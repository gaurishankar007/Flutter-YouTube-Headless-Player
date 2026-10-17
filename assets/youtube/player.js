/**
 * player.js — headless playback engine around the official YouTube
 * IFrame Player API.
 *
 * Responsibilities:
 *   - Load the IFrame API script lazily and create a chrome-less player.
 *   - Receive JSON commands from Flutter through a single dispatcher
 *     (`window.youtubeHeadlessPlayer.dispatch({action, ...params})`).
 *   - Push structured JSON events to Flutter — the `webview_flutter`
 *     JavaScript channel on native, `postMessage` on web — never plain
 *     strings.
 *   - Emit progress events every 250 ms while playing, and stop while
 *     paused / buffering / ended.
 *
 * This file renders NO user interface. Flutter owns 100% of the UI.
 *
 * The only globals introduced are `window.youtubeHeadlessPlayer` (the public
 * wrapper) and `window.onYouTubeIframeAPIReady` (mandated by the IFrame API
 * itself; the previous value, if any, is chained).
 */
(() => {
  'use strict';

  /** Name of the Flutter-side JavaScript channel receiving player events. */
  const EVENT_CHANNEL = 'YoutubePlayerEvents';

  /** Interval between progress events while the video is playing. */
  const PROGRESS_INTERVAL_MS = 250;

  /** Interval between `pageReady` announcements awaiting initialization. */
  const PAGE_READY_INTERVAL_MS = 300;

  /** Upper bound on `pageReady` announcements (~30 seconds). */
  const MAX_PAGE_READY_ANNOUNCEMENTS = 100;

  /**
   * Grace period after a volume/mute command during which read-back drift
   * checks are suspended. The IFrame proxy applies commands asynchronously,
   * so immediate read-backs still report the previous state.
   */
  const VOLUME_SYNC_GRACE_MS = 1000;

  /** Official IFrame API loader script. */
  const IFRAME_API_SRC = 'https://www.youtube.com/iframe_api';

  /** DOM id of the element the IFrame API replaces with the player. */
  const PLAYER_ELEMENT_ID = 'player';

  /** Human readable messages for the documented IFrame API error codes. */
  const ERROR_MESSAGES = Object.freeze({
    2: 'The request contains an invalid video id or parameter value.',
    5: 'The requested content cannot be played in an HTML5 player.',
    100: 'The requested video was not found (removed or private).',
    101: 'The owner of the requested video does not allow embedded playback.',
    150: 'The owner of the requested video does not allow embedded playback.',
    // Undocumented variants of 150 raised for embed configuration problems
    // (e.g. an origin/referer YouTube does not accept).
    152: 'YouTube rejected the embed configuration for this video.',
    153: 'YouTube rejected the embed request (missing or invalid referer).',
  });

  /**
   * One-way JSON event pipe from JavaScript to Flutter.
   *
   * Every payload is a plain object with a mandatory `event` field, e.g.
   * `{event: 'progress', position: 12.3, duration: 100, buffered: 0.44}`.
   *
   * On Android/iOS/macOS events travel as JSON strings through the
   * `webview_flutter` JavaScript channel. On Flutter Web the engine runs in
   * an iframe instead, so events are posted to the parent window as JSON
   * strings tagged with this player's instance id (taken from the
   * `playerId` query parameter).
   */
  class EventChannel {
    constructor() {
      this._playerId = new URLSearchParams(window.location.search).get(
        'playerId',
      );
    }

    /**
     * Posts a structured event to Flutter.
     *
     * @param {string} event Event name understood by the Dart bridge.
     * @param {Object} [data] Additional event payload fields.
     */
    post(event, data = {}) {
      const payload = Object.assign({ event }, data);
      const channel = window[EVENT_CHANNEL];
      if (channel && typeof channel.postMessage === 'function') {
        channel.postMessage(JSON.stringify(payload));
        return;
      }
      if (window.parent && window.parent !== window) {
        // The payload only ever contains non-sensitive playback state, so a
        // wildcard target origin is acceptable here.
        window.parent.postMessage(
          JSON.stringify({
            source: 'youtubeHeadlessPlayer',
            playerId: this._playerId,
            payload,
          }),
          '*',
        );
      }
    }
  }

  /**
   * Owns the 250 ms progress timer. Started when playback starts and
   * stopped when playback pauses, buffers or ends, so the bridge carries
   * no traffic while the player is idle.
   */
  class ProgressReporter {
    /** @param {function(): void} onTick Called on every interval tick. */
    constructor(onTick) {
      this._onTick = onTick;
      this._timerId = null;
    }

    /** Starts the periodic reporting if it is not already running. */
    start() {
      if (this._timerId !== null) {
        return;
      }
      this._timerId = setInterval(this._onTick, PROGRESS_INTERVAL_MS);
    }

    /** Stops the periodic reporting if it is running. */
    stop() {
      if (this._timerId === null) {
        return;
      }
      clearInterval(this._timerId);
      this._timerId = null;
    }
  }

  /**
   * Thin, stateful wrapper around `YT.Player`.
   *
   * Translates IFrame API callbacks into channel events and exposes the
   * imperative playback surface consumed by the command dispatcher.
   */
  class YoutubePlayerEngine {
    /** @param {EventChannel} channel Event pipe towards Flutter. */
    constructor(channel) {
      this._channel = channel;
      this._player = null;
      this._apiPromise = null;
      this._initPromise = null;
      this._lastDuration = -1;
      this._lastVolume = 100;
      this._lastMuted = false;
      this._volumeSyncPausedUntil = 0;
      this._captionsEnabled = false;
      this._captionsLanguage = null;
      this._captionsSyncPending = false;
      this._reporter = new ProgressReporter(() => this._emitProgress());
    }

    /**
     * Loads the IFrame API (once) and creates the player.
     *
     * Idempotent: repeated calls (Flutter retries the command until the
     * engine acknowledges it) all resolve with the same initialization.
     *
     * @param {Object} config Initialization options sent from Flutter:
     *   `videoId`, `autoPlay`, `muted`, `loop`, `startSeconds`,
     *   `endSeconds`, `interfaceLanguage`, `captionsEnabled`,
     *   `captionsLanguage`.
     * @returns {Promise<void>} Resolves once the player object exists.
     */
    initialize(config = {}) {
      if (this._initPromise === null) {
        this._captionsEnabled = config.captionsEnabled === true;
        this._captionsLanguage =
          typeof config.captionsLanguage === 'string'
            ? config.captionsLanguage
            : null;
        this._initPromise = this._loadIframeApi().then(() =>
          this._createPlayer(config),
        );
      }
      return this._initPromise;
    }

    /** Loads and starts playing the given video. */
    load(videoId, startSeconds, endSeconds) {
      const player = this._requirePlayer();
      if (player === null) {
        return;
      }
      this._lastDuration = -1;
      this._captionsSyncPending = true;
      player.loadVideoById({
        videoId,
        startSeconds: typeof startSeconds === 'number' ? startSeconds : undefined,
        endSeconds: typeof endSeconds === 'number' ? endSeconds : undefined,
      });
      this._channel.post('videoLoaded', { videoId });
    }

    /** Cues the given video without starting playback. */
    cue(videoId, startSeconds, endSeconds) {
      const player = this._requirePlayer();
      if (player === null) {
        return;
      }
      this._lastDuration = -1;
      this._captionsSyncPending = true;
      player.cueVideoById({
        videoId,
        startSeconds: typeof startSeconds === 'number' ? startSeconds : undefined,
        endSeconds: typeof endSeconds === 'number' ? endSeconds : undefined,
      });
    }

    play() {
      const player = this._requirePlayer();
      if (player !== null) {
        player.playVideo();
      }
    }

    pause() {
      const player = this._requirePlayer();
      if (player !== null) {
        player.pauseVideo();
      }
    }

    stop() {
      const player = this._requirePlayer();
      if (player !== null) {
        this._reporter.stop();
        player.stopVideo();
      }
    }

    seekTo(seconds, allowSeekAhead = true) {
      const player = this._requirePlayer();
      if (player !== null && typeof seconds === 'number') {
        player.seekTo(seconds, allowSeekAhead !== false);
        // Read-backs right after a seek still report the old position, so
        // this snapshot carries the requested target; Flutter latches onto
        // it until the engine's reported position catches up.
        this._channel.post('progress', {
          position: seconds,
          duration: player.getDuration() || 0,
          buffered: player.getVideoLoadedFraction() || 0,
        });
      }
    }

    mute() {
      const player = this._requirePlayer();
      if (player !== null) {
        player.mute();
        this._postVolumeState(this._lastVolume, true);
      }
    }

    unMute() {
      const player = this._requirePlayer();
      if (player !== null) {
        player.unMute();
        this._postVolumeState(this._lastVolume, false);
      }
    }

    setVolume(volume) {
      const player = this._requirePlayer();
      if (player !== null && typeof volume === 'number') {
        const clamped = Math.min(100, Math.max(0, Math.round(volume)));
        player.setVolume(clamped);
        this._postVolumeState(clamped, this._lastMuted);
      }
    }

    getVolume() {
      const player = this._requirePlayer();
      return player === null ? null : player.getVolume();
    }

    isMuted() {
      const player = this._requirePlayer();
      return player === null ? null : player.isMuted();
    }

    setPlaybackRate(rate) {
      const player = this._requirePlayer();
      if (player !== null && typeof rate === 'number') {
        player.setPlaybackRate(rate);
      }
    }

    getPlaybackRate() {
      const player = this._requirePlayer();
      return player === null ? null : player.getPlaybackRate();
    }

    getAvailablePlaybackRates() {
      const player = this._requirePlayer();
      return player === null ? [] : player.getAvailablePlaybackRates();
    }

    /**
     * Requests a playback quality.
     *
     * The documented `setPlaybackQuality` has been a no-op for years, so
     * the (undocumented but functional) `setPlaybackQualityRange` is used
     * to pin the adaptive selector to the requested level; `default`
     * releases the pin and restores automatic selection.
     */
    setPlaybackQuality(quality) {
      const player = this._requirePlayer();
      if (player === null || typeof quality !== 'string') {
        return;
      }
      if (typeof player.setPlaybackQualityRange === 'function') {
        if (quality === 'default') {
          player.setPlaybackQualityRange('auto', 'auto');
        } else {
          player.setPlaybackQualityRange(quality, quality);
        }
      }
      player.setPlaybackQuality(quality);
    }

    getPlaybackQuality() {
      const player = this._requirePlayer();
      return player === null ? null : player.getPlaybackQuality();
    }

    getAvailableQualityLevels() {
      const player = this._requirePlayer();
      return player === null ? [] : player.getAvailableQualityLevels();
    }

    /**
     * Turns closed captions on or off via the IFrame API module system
     * (`loadModule`/`unloadModule`), which — unlike quality selection —
     * still works on the current player. Captions only render for videos
     * that actually provide (or auto-generate) a caption track.
     */
    setCaptionsEnabled(enabled) {
      const player = this._requirePlayer();
      if (player === null) {
        return;
      }
      this._captionsEnabled = enabled === true;
      this._applyCaptionsState();
      this._channel.post('captionsChanged', {
        enabled: this._captionsEnabled,
      });
    }

    /**
     * Enforces the configured captions state on the player.
     *
     * YouTube applies its own default (the viewer's saved caption
     * preference, or auto-caption heuristics), so "off" must be enforced
     * with an explicit `unloadModule` — merely omitting `cc_load_policy`
     * is not enough. Re-applied after every video load, because a new
     * video re-evaluates the viewer preference.
     */
    _applyCaptionsState() {
      if (this._player === null) {
        return;
      }
      if (this._captionsEnabled) {
        this._player.loadModule('captions');
        if (this._captionsLanguage !== null) {
          this._player.setOption('captions', 'track', {
            languageCode: this._captionsLanguage,
          });
        }
      } else {
        this._player.unloadModule('captions');
      }
    }

    getDuration() {
      const player = this._requirePlayer();
      return player === null ? null : player.getDuration();
    }

    getCurrentTime() {
      const player = this._requirePlayer();
      return player === null ? null : player.getCurrentTime();
    }

    getBufferedFraction() {
      const player = this._requirePlayer();
      return player === null ? null : player.getVideoLoadedFraction();
    }

    /** Stops all timers and destroys the underlying player. */
    destroy() {
      this._reporter.stop();
      if (this._player !== null) {
        this._player.destroy();
        this._player = null;
      }
    }

    /**
     * Injects the IFrame API script once and resolves when it is ready.
     *
     * @returns {Promise<void>}
     */
    _loadIframeApi() {
      if (this._apiPromise !== null) {
        return this._apiPromise;
      }
      this._apiPromise = new Promise((resolve, reject) => {
        if (window.YT && typeof window.YT.Player === 'function') {
          resolve();
          return;
        }
        // The IFrame API invokes this exact global when it finishes loading;
        // chain any pre-existing handler instead of clobbering it.
        const previousHandler = window.onYouTubeIframeAPIReady;
        window.onYouTubeIframeAPIReady = () => {
          if (typeof previousHandler === 'function') {
            previousHandler();
          }
          resolve();
        };
        const script = document.createElement('script');
        script.src = IFRAME_API_SRC;
        script.onerror = () => {
          this._apiPromise = null;
          reject(new Error('Failed to load the YouTube IFrame API script.'));
        };
        document.head.appendChild(script);
      });
      return this._apiPromise;
    }

    /**
     * Creates the chrome-less `YT.Player` instance.
     *
     * @param {Object} config See {@link initialize}.
     * @returns {Promise<void>} Resolves once the constructor returns.
     */
    _createPlayer(config) {
      return new Promise((resolve) => {
        this._player = new window.YT.Player(PLAYER_ELEMENT_ID, {
          width: '100%',
          height: '100%',
          videoId: typeof config.videoId === 'string' ? config.videoId : undefined,
          playerVars: this._buildPlayerVars(config),
          events: {
            onReady: () => {
              this._onReady(config);
              resolve();
            },
            onStateChange: (event) => this._onStateChange(event),
            onPlaybackQualityChange: (event) =>
              this._channel.post('qualityChanged', {
                quality: event.data,
                availableQualities:
                  this._player !== null
                    ? this._player.getAvailableQualityLevels()
                    : [],
              }),
            onPlaybackRateChange: (event) =>
              this._channel.post('playbackRateChanged', { rate: event.data }),
            onError: (event) => this._onError(event),
          },
        });
      });
    }

    /**
     * Builds the `playerVars` that keep the embedded player completely
     * chrome-less: no controls, no keyboard handling, no fullscreen button,
     * no related videos and no annotations.
     */
    _buildPlayerVars(config) {
      const playerVars = {
        autoplay: config.autoPlay ? 1 : 0,
        mute: config.muted ? 1 : 0,
        controls: 0,
        disablekb: 1,
        enablejsapi: 1,
        fs: 0,
        iv_load_policy: 3,
        modestbranding: 1,
        playsinline: 1,
        rel: 0,
      };
      if (typeof config.startSeconds === 'number') {
        playerVars.start = Math.floor(config.startSeconds);
      }
      if (typeof config.endSeconds === 'number') {
        playerVars.end = Math.floor(config.endSeconds);
      }
      if (typeof config.interfaceLanguage === 'string') {
        playerVars.hl = config.interfaceLanguage;
      }
      if (config.captionsEnabled === true) {
        // Show captions from the start (user preference permitting).
        playerVars.cc_load_policy = 1;
      }
      if (typeof config.captionsLanguage === 'string') {
        playerVars.cc_lang_pref = config.captionsLanguage;
      }
      if (config.loop && typeof config.videoId === 'string') {
        // The IFrame API only honors `loop` for playlists, so the video is
        // registered as a single-item playlist of itself.
        playerVars.loop = 1;
        playerVars.playlist = config.videoId;
      }
      // Pass the page origin only when it is a genuine application origin
      // (Flutter Web). On Android/iOS/macOS the document is loaded under a
      // YouTube base URL, and echoing that spoofed origin back to the API
      // makes YouTube reject playback with embed errors (150/152/153).
      const origin = window.location.origin;
      const isYoutubeHost = /(^|\.)youtube(-nocookie)?\.com$/.test(
        window.location.hostname,
      );
      if (origin && origin.startsWith('http') && !isYoutubeHost) {
        playerVars.origin = origin;
      }
      return playerVars;
    }

    /** Announces readiness together with the initial playback snapshot. */
    _onReady(config) {
      if (config.muted) {
        // Some platforms ignore the `mute` player var; enforce it explicitly
        // so muted autoplay is reliable under autoplay policies.
        this._player.mute();
      }
      this._lastVolume = this._player.getVolume();
      this._lastMuted = config.muted === true || this._player.isMuted();
      this._applyCaptionsState();
      this._captionsSyncPending = true;
      this._channel.post('ready', {
        duration: this._player.getDuration(),
        volume: this._player.getVolume(),
        muted: this._player.isMuted(),
        rate: this._player.getPlaybackRate(),
        availableRates: this._player.getAvailablePlaybackRates(),
        quality: this._player.getPlaybackQuality(),
        availableQualities: this._player.getAvailableQualityLevels(),
      });
    }

    /** Maps `YT.PlayerState` transitions to channel events. */
    _onStateChange(event) {
      const states = window.YT.PlayerState;
      switch (event.data) {
        case states.PLAYING:
          this._checkDurationChanged();
          if (this._captionsSyncPending) {
            // The module system only takes effect once playback runs, so
            // the configured captions state is enforced on the first
            // PLAYING transition of each video.
            this._captionsSyncPending = false;
            this._applyCaptionsState();
          }
          this._channel.post('playing');
          this._reporter.start();
          break;
        case states.PAUSED:
          this._reporter.stop();
          this._emitProgress();
          this._channel.post('paused');
          break;
        case states.BUFFERING:
          this._reporter.stop();
          this._channel.post('buffering');
          break;
        case states.ENDED:
          this._reporter.stop();
          this._emitProgress();
          this._channel.post('ended');
          break;
        case states.CUED:
          this._reporter.stop();
          this._checkDurationChanged();
          this._channel.post('videoCued', {
            videoId: this._currentVideoId(),
          });
          break;
        case states.UNSTARTED:
          this._reporter.stop();
          this._channel.post('idle');
          break;
        default:
          break;
      }
    }

    /** Translates an IFrame API error code into a structured event. */
    _onError(event) {
      this._reporter.stop();
      const code = event.data;
      this._channel.post('error', {
        code,
        message: ERROR_MESSAGES[code] || 'An unknown playback error occurred.',
      });
    }

    /** Emits one progress snapshot; also watches for duration changes. */
    _emitProgress() {
      if (this._player === null) {
        return;
      }
      this._checkDurationChanged();
      this._syncVolumeState();
      this._channel.post('progress', {
        position: this._player.getCurrentTime() || 0,
        duration: this._player.getDuration() || 0,
        buffered: this._player.getVideoLoadedFraction() || 0,
      });
    }

    /**
     * Announces a volume state and remembers it as the source of truth.
     *
     * Commands are announced with their *intended* state rather than a
     * read-back, because the IFrame proxy applies them asynchronously and
     * immediate read-backs still report the previous state. Drift checks
     * are paused for a grace period so the stale read-back cannot fight
     * the announcement.
     */
    _postVolumeState(volume, muted) {
      this._lastVolume = volume;
      this._lastMuted = muted;
      this._volumeSyncPausedUntil = Date.now() + VOLUME_SYNC_GRACE_MS;
      this._channel.post('volumeChanged', { volume, muted });
    }

    /**
     * Reconciles the announced volume state with the player's real state
     * (the API has no native volume event). Runs on progress ticks, so if
     * the browser refused a command the UI corrects within a tick.
     */
    _syncVolumeState() {
      if (Date.now() < this._volumeSyncPausedUntil) {
        return;
      }
      const volume = this._player.getVolume();
      const muted = this._player.isMuted();
      if (
        typeof volume === 'number' &&
        (volume !== this._lastVolume || muted !== this._lastMuted)
      ) {
        this._postVolumeState(volume, muted);
      }
    }

    /** Emits `durationChanged` whenever the reported duration moves. */
    _checkDurationChanged() {
      const duration = this._player.getDuration() || 0;
      if (duration > 0 && duration !== this._lastDuration) {
        this._lastDuration = duration;
        this._channel.post('durationChanged', { duration });
      }
    }

    /** Extracts the current video id from the player, if available. */
    _currentVideoId() {
      const data = this._player.getVideoData ? this._player.getVideoData() : null;
      return data && data.video_id ? data.video_id : null;
    }

    /**
     * Returns the player or `null` when it does not exist yet. Commands
     * arriving before readiness are queued on the Flutter side, so a silent
     * no-op here is safe and keeps the bridge free of error noise.
     */
    _requirePlayer() {
      return this._player;
    }
  }

  /**
   * The single public wrapper exposed to Flutter.
   *
   * Provides the full imperative API plus `dispatch`, the JSON command
   * entry point used by the Dart bridge so no raw JavaScript needs to be
   * generated per command.
   */
  class YoutubeHeadlessPlayer {
    constructor() {
      this._channel = new EventChannel();
      this._engine = new YoutubePlayerEngine(this._channel);
      this._announceTimer = null;
      this._startPageReadyAnnouncements();
    }

    /**
     * Repeatedly announces that the engine page is ready to be initialized.
     *
     * The Flutter side answers every announcement with an `initialize`
     * command (idempotent), which closes the race where a command evaluated
     * against the page before this script finished loading is silently
     * dropped. Announcements stop as soon as `initialize` arrives, or after
     * `MAX_PAGE_READY_ANNOUNCEMENTS` attempts.
     */
    _startPageReadyAnnouncements() {
      let attempts = 0;
      this._channel.post('pageReady');
      this._announceTimer = setInterval(() => {
        attempts += 1;
        if (attempts >= MAX_PAGE_READY_ANNOUNCEMENTS) {
          this._stopPageReadyAnnouncements();
          return;
        }
        this._channel.post('pageReady');
      }, PAGE_READY_INTERVAL_MS);
    }

    /** Stops the `pageReady` announcement loop. */
    _stopPageReadyAnnouncements() {
      if (this._announceTimer !== null) {
        clearInterval(this._announceTimer);
        this._announceTimer = null;
      }
    }

    /**
     * Executes a JSON command, e.g. `{action: 'seekTo', seconds: 120}`.
     *
     * @param {Object|string} command Command object or its JSON encoding.
     * @returns {*} The return value of the invoked function, if any.
     */
    dispatch(command) {
      let parsed = command;
      if (typeof command === 'string') {
        try {
          parsed = JSON.parse(command);
        } catch (_) {
          this._channel.post('error', {
            code: -1,
            message: 'Received a command that is not valid JSON.',
          });
          return null;
        }
      }
      const action = parsed && parsed.action;
      switch (action) {
        case 'initialize':
          this._stopPageReadyAnnouncements();
          return this.initialize(parsed);
        case 'load':
          return this.load(parsed.videoId, parsed.startSeconds, parsed.endSeconds);
        case 'cue':
          return this.cue(parsed.videoId, parsed.startSeconds, parsed.endSeconds);
        case 'play':
          return this.play();
        case 'pause':
          return this.pause();
        case 'stop':
          return this.stop();
        case 'seekTo':
          return this.seekTo(parsed.seconds, parsed.allowSeekAhead);
        case 'mute':
          return this.mute();
        case 'unMute':
          return this.unMute();
        case 'setVolume':
          return this.setVolume(parsed.volume);
        case 'getVolume':
          return this.getVolume();
        case 'setPlaybackRate':
          return this.setPlaybackRate(parsed.rate);
        case 'getPlaybackRate':
          return this.getPlaybackRate();
        case 'getAvailablePlaybackRates':
          return this.getAvailablePlaybackRates();
        case 'setPlaybackQuality':
          return this.setPlaybackQuality(parsed.quality);
        case 'getPlaybackQuality':
          return this.getPlaybackQuality();
        case 'getAvailableQualityLevels':
          return this.getAvailableQualityLevels();
        case 'setCaptionsEnabled':
          return this.setCaptionsEnabled(parsed.enabled);
        case 'getDuration':
          return this.getDuration();
        case 'getCurrentTime':
          return this.getCurrentTime();
        case 'getBufferedFraction':
          return this.getBufferedFraction();
        case 'isMuted':
          return this.isMuted();
        case 'destroy':
          return this.destroy();
        default:
          this._channel.post('error', {
            code: -1,
            message: `Received an unknown command action: "${action}".`,
          });
          return null;
      }
    }

    initialize(config) {
      return this._engine.initialize(config).catch((error) => {
        this._channel.post('error', {
          code: -2,
          message: error && error.message
            ? error.message
            : 'Failed to initialize the YouTube player.',
        });
      });
    }

    load(videoId, startSeconds, endSeconds) {
      this._engine.load(videoId, startSeconds, endSeconds);
    }

    cue(videoId, startSeconds, endSeconds) {
      this._engine.cue(videoId, startSeconds, endSeconds);
    }

    play() {
      this._engine.play();
    }

    pause() {
      this._engine.pause();
    }

    stop() {
      this._engine.stop();
    }

    seekTo(seconds, allowSeekAhead) {
      this._engine.seekTo(seconds, allowSeekAhead);
    }

    mute() {
      this._engine.mute();
    }

    unMute() {
      this._engine.unMute();
    }

    setVolume(volume) {
      this._engine.setVolume(volume);
    }

    getVolume() {
      return this._engine.getVolume();
    }

    setPlaybackRate(rate) {
      this._engine.setPlaybackRate(rate);
    }

    getPlaybackRate() {
      return this._engine.getPlaybackRate();
    }

    getAvailablePlaybackRates() {
      return this._engine.getAvailablePlaybackRates();
    }

    setPlaybackQuality(quality) {
      this._engine.setPlaybackQuality(quality);
    }

    getPlaybackQuality() {
      return this._engine.getPlaybackQuality();
    }

    getAvailableQualityLevels() {
      return this._engine.getAvailableQualityLevels();
    }

    setCaptionsEnabled(enabled) {
      this._engine.setCaptionsEnabled(enabled);
    }

    getDuration() {
      return this._engine.getDuration();
    }

    getCurrentTime() {
      return this._engine.getCurrentTime();
    }

    getBufferedFraction() {
      return this._engine.getBufferedFraction();
    }

    isMuted() {
      return this._engine.isMuted();
    }

    destroy() {
      this._engine.destroy();
    }
  }

  /**
   * Blocks context menus, text selection and drag gestures so the page
   * never shows browser affordances behind the Flutter UI.
   */
  const suppressBrowserInteractions = () => {
    for (const type of ['contextmenu', 'selectstart', 'dragstart']) {
      document.addEventListener(type, (event) => event.preventDefault(), {
        passive: false,
      });
    }
  };

  /**
   * On Flutter Web the engine runs in a same-origin iframe that sits in the
   * DOM alongside Flutter's canvases. Without this, the iframe element
   * captures every pointer event over the video, so the Flutter controls
   * painted on top never receive taps. The player must never be interacted
   * with directly (Flutter owns 100% of the UI), so the hosting iframe is
   * made fully transparent to pointer events. No-op on Android/iOS/macOS,
   * where the document is the top-level frame.
   */
  const disableHostFramePointerEvents = () => {
    try {
      let element = window.frameElement;
      while (element && element.tagName !== 'FLT-PLATFORM-VIEW') {
        element.style.pointerEvents = 'none';
        element = element.parentElement;
      }
    } catch (_) {
      // Cross-origin embedding: leave the frame untouched.
    }
  };

  window.youtubeHeadlessPlayer = new YoutubeHeadlessPlayer();
  suppressBrowserInteractions();
  disableHostFramePointerEvents();
})();
