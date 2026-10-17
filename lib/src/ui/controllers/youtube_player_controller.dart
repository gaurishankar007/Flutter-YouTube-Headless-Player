import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:youtube_headless_player/src/core/constants/youtube_thumbnail_quality.dart';
import 'package:youtube_headless_player/src/core/utils/youtube_fullscreen_manager.dart';
import 'package:youtube_headless_player/src/core/utils/youtube_thumbnail_util.dart';
import 'package:youtube_headless_player/src/core/utils/youtube_url_parser.dart';
import 'package:youtube_headless_player/src/data/services/youtube_bridge.dart';
import 'package:youtube_headless_player/src/domain/models/youtube_player_event.dart';
import 'package:youtube_headless_player/src/domain/models/youtube_player_value.dart';
import 'package:youtube_headless_player/src/domain/models/youtube_quality.dart';
import 'package:youtube_headless_player/src/ui/controllers/youtube_controller_impl.dart';

/// Controls a `YoutubePlayer` widget and publishes its state.
///
/// Modeled after Flutter's `VideoPlayerController`: the controller is a
/// [ValueNotifier] whose [value] is an immutable [YoutubePlayerValue]
/// snapshot, and [events] exposes the same information as a stream of
/// typed [YoutubePlayerEvent]s for imperative listeners.
///
/// The initial video can be given as a bare id, or as any common YouTube
/// URL form via [YoutubePlayerController.fromUrl]:
///
/// ```dart
/// final controller = YoutubePlayerController(
///   initialVideoId: 'dQw4w9WgXcQ',
///   autoPlay: true,
///   startMuted: true,
/// );
/// // ...or equivalently:
/// final controller = YoutubePlayerController.fromUrl(
///   'https://youtu.be/dQw4w9WgXcQ',
/// );
/// ```
///
/// Commands issued before the underlying player is ready are queued and
/// flushed automatically once it becomes ready. Always call [dispose] when
/// the controller is no longer needed.
class YoutubePlayerController extends ValueNotifier<YoutubePlayerValue> {
  /// Creates a controller, optionally configured with an initial video id.
  ///
  /// To start from a YouTube URL instead, use
  /// [YoutubePlayerController.fromUrl].
  new({
    this.initialVideoId,
    this.autoPlay = false,
    this.startMuted = false,
    this.loop = false,
    this.startAt,
    this.endAt,
    this.interfaceLanguage,
    this.captionsEnabled = false,
    this.captionsLanguage,
    this.fullscreenOrientations = const [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ],
    this.portraitFullscreenOrientations = const [DeviceOrientation.portraitUp],
    this.videoAspectRatio = defaultVideoAspectRatio,
  }) : super(
         YoutubePlayerValue(
           videoId: initialVideoId,
           captionsEnabled: captionsEnabled,
         ),
       );

  /// Creates a controller whose initial video is given by [videoUrl] —
  /// any common YouTube URL form (`watch?v=`, `youtu.be/`, `embed/`,
  /// `shorts/`, `live/`) or a bare video id; see [convertUrlToId].
  ///
  /// In debug mode, asserts that a video id can be extracted from
  /// [videoUrl]; in release, an unparseable URL results in a controller
  /// with no initial video.
  new fromUrl(
    String videoUrl, {
    this.autoPlay = false,
    this.startMuted = false,
    this.loop = false,
    this.startAt,
    this.endAt,
    this.interfaceLanguage,
    this.captionsEnabled = false,
    this.captionsLanguage,
    this.fullscreenOrientations = const [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ],
    this.portraitFullscreenOrientations = const [DeviceOrientation.portraitUp],
    this.videoAspectRatio = defaultVideoAspectRatio,
  }) : assert(
         youtubeVideoIdFromUrl(videoUrl) != null,
         'No YouTube video id could be extracted from videoUrl: '
         '"$videoUrl".',
       ),
       initialVideoId = youtubeVideoIdFromUrl(videoUrl),
       super(
         YoutubePlayerValue(
           videoId: youtubeVideoIdFromUrl(videoUrl),
           captionsEnabled: captionsEnabled,
         ),
       );

  /// How long [loadNewVideo] waits for the replacement video to report
  /// itself running before giving up on restoring the paused state.
  static const Duration _loadNewVideoSettleTimeout = Duration(seconds: 10);

  /// The video loaded (or cued, when [autoPlay] is false) at startup.
  ///
  /// When the controller was created with
  /// [YoutubePlayerController.fromUrl], this holds the id extracted from
  /// that URL.
  final String? initialVideoId;

  /// Whether playback starts automatically once the player is ready.
  ///
  /// Browsers and mobile WebViews generally only allow autoplay when the
  /// player [startMuted]; combine the two for reliable autoplay.
  final bool autoPlay;

  /// Whether the player starts muted.
  final bool startMuted;

  /// Whether the initial video restarts automatically when it ends.
  final bool loop;

  /// Position at which the initial video starts playing.
  final Duration? startAt;

  /// Position at which the initial video stops playing.
  final Duration? endAt;

  /// ISO 639-1 language code for the player interface (captions menu etc.).
  final String? interfaceLanguage;

  /// Whether closed captions start enabled.
  ///
  /// Captions only render for videos that provide (or auto-generate) a
  /// caption track; toggle at runtime with [setCaptionsEnabled].
  final bool captionsEnabled;

  /// ISO 639-1 language code of the preferred caption track (e.g. `'en'`).
  final String? captionsLanguage;

  /// Aspect ratio assumed when the video's real one isn't known.
  static const double defaultVideoAspectRatio = 16 / 9;

  /// Orientations forced while in fullscreen for landscape videos
  /// (mobile only).
  final List<DeviceOrientation> fullscreenOrientations;

  /// Orientations forced while in fullscreen for portrait videos
  /// (mobile only); see [isPortraitVideo].
  final List<DeviceOrientation> portraitFullscreenOrientations;

  /// Width / height of the video itself, used to size the video surface
  /// and to pick the fullscreen orientation.
  ///
  /// YouTube doesn't expose a video's dimensions to the embedded player, so
  /// pass the real value when it's known (e.g. from the YouTube Data API's
  /// `player.embedWidth` / `player.embedHeight`).
  final double videoAspectRatio;

  /// Whether the video is taller than it is wide.
  bool get isPortraitVideo => videoAspectRatio < 1;

  bool _isDisposed = false;

  YoutubeControllerImpl get _impl => youtubeControllerImplOf(this);

  /// Typed player events (state changes, progress, errors, ...).
  ///
  /// A broadcast stream — subscribe as many listeners as needed.
  Stream<YoutubePlayerEvent> get events => _impl.events;

  /// Loads a new video and starts playing it.
  Future<void> loadVideo(String videoId, {Duration? startAt, Duration? endAt}) {
    return _impl.enqueue(
      YoutubeCommand('load', {
        'videoId': videoId,
        if (startAt != null) 'startSeconds': _seconds(startAt),
        if (endAt != null) 'endSeconds': _seconds(endAt),
      }),
    );
  }

  /// Cues a new video without starting playback.
  Future<void> cueVideo(String videoId, {Duration? startAt, Duration? endAt}) {
    return _impl.enqueue(
      YoutubeCommand('cue', {
        'videoId': videoId,
        if (startAt != null) 'startSeconds': _seconds(startAt),
        if (endAt != null) 'endSeconds': _seconds(endAt),
      }),
    );
  }

  /// Replaces the current video with the one in [videoUrl], resuming from
  /// the current playback position.
  ///
  /// Designed for switching between alternate recordings of the same
  /// content (e.g. camera angles): the new video starts where the old one
  /// left off. Pass [startAt] to resume from a different position instead.
  ///
  /// [videoUrl] accepts any common YouTube URL form (`watch?v=`,
  /// `youtu.be/`, `embed/`, `shorts/`, `live/`) or a bare video id; see
  /// [convertUrlToId]. Throws an [ArgumentError] when no video id can be
  /// extracted.
  ///
  /// Loading always starts playback. If the player was paused, it is
  /// paused again as soon as the new video reports itself running, so a
  /// frame of the new video stays visible instead of a black surface.
  Future<void> loadNewVideo(String videoUrl, {Duration? startAt}) async {
    final videoId = convertUrlToId(videoUrl);
    if (videoId == null) {
      throw ArgumentError.value(
        videoUrl,
        'videoUrl',
        'No YouTube video id could be extracted',
      );
    }
    final wasPlaying = value.isPlaying;
    await loadVideo(videoId, startAt: startAt ?? value.position);
    if (wasPlaying) {
      return;
    }
    // `load` auto-plays; wait until the engine reports the new video
    // running (or failing), then pause to restore the previous state.
    // `toList` (instead of `firstWhere`) completes with an empty list when
    // the stream closes mid-wait, e.g. because the controller was disposed.
    try {
      final settled = await events
          .where(
            (event) =>
                event is PlayingEvent ||
                event is VideoCuedEvent ||
                event is ErrorEvent,
          )
          .take(1)
          .toList()
          .timeout(_loadNewVideoSettleTimeout);
      if (settled.isNotEmpty && settled.first is! ErrorEvent) {
        await pause();
      }
    } on TimeoutException {
      // The engine never reported the new video; leave playback as-is.
    }
  }

  /// Extracts the 11-character video id from any common YouTube URL form
  /// (`watch?v=`, `youtu.be/`, `embed/`, `shorts/`, `live/`, `/v/`, with or
  /// without scheme/subdomain/extra query parameters). A bare video id is
  /// passed through unchanged. Returns `null` when no id can be found.
  static String? convertUrlToId(String url) => youtubeVideoIdFromUrl(url);

  /// Builds the thumbnail image URL for a [videoId].
  ///
  /// [webp] selects the WebP variant (smaller files); pass `false` for
  /// JPEG. See [YoutubeThumbnailQuality] for the available resolutions.
  static String getThumbnail({
    required String videoId,
    YoutubeThumbnailQuality quality = YoutubeThumbnailQuality.standard,
    bool webp = true,
  }) {
    return youtubeThumbnailUrl(videoId: videoId, quality: quality, webp: webp);
  }

  /// Builds the thumbnail image URL for a video given by [videoUrl] —
  /// any common YouTube URL form or a bare video id (see [convertUrlToId]).
  ///
  /// Returns `null` when no video id can be extracted.
  static String? getThumbnailUrl(
    String videoUrl, {
    YoutubeThumbnailQuality quality = YoutubeThumbnailQuality.standard,
    bool webp = true,
  }) {
    final videoId = convertUrlToId(videoUrl);
    if (videoId == null) {
      return null;
    }
    return youtubeThumbnailUrl(videoId: videoId, quality: quality, webp: webp);
  }

  /// The thumbnail image URL of the currently loaded (or initial) video,
  /// or `null` when no video is set. Useful as the `YoutubePlayer`
  /// placeholder while the player initializes.
  String? thumbnailUrl({
    YoutubeThumbnailQuality quality = YoutubeThumbnailQuality.standard,
    bool webp = true,
  }) {
    final videoId = value.videoId ?? initialVideoId;
    if (videoId == null || videoId.isEmpty) {
      return null;
    }
    return youtubeThumbnailUrl(videoId: videoId, quality: quality, webp: webp);
  }

  /// Starts or resumes playback.
  Future<void> play() => _impl.enqueue(const YoutubeCommand('play'));

  /// Pauses playback.
  Future<void> pause() => _impl.enqueue(const YoutubeCommand('pause'));

  /// Stops playback and returns the player to the idle state.
  Future<void> stop() => _impl.enqueue(const YoutubeCommand('stop'));

  /// Seeks to [position] (clamped to the video's duration).
  ///
  /// The position is applied to [value] immediately and *latched*: stale
  /// progress reports cannot move the scrubber back while the engine is
  /// still executing the seek, mirroring the real YouTube player.
  ///
  /// Set [allowSeekAhead] to `false` while scrubbing continuously to avoid
  /// firing a server request for every intermediate position; issue a final
  /// seek with `true` when the scrub gesture ends.
  Future<void> seekTo(Duration position, {bool allowSeekAhead = true}) {
    var target = position < Duration.zero ? Duration.zero : position;
    final duration = value.duration;
    if (duration > Duration.zero && target > duration) {
      target = duration;
    }
    _impl.registerSeek(target);
    return _impl.enqueue(
      YoutubeCommand('seekTo', {
        'seconds': _seconds(target),
        'allowSeekAhead': allowSeekAhead,
      }),
    );
  }

  /// Replays the current video from the beginning.
  Future<void> replay() async {
    await seekTo(Duration.zero);
    await play();
  }

  /// Sets the player volume, clamped between `0` and `100`.
  ///
  /// [value] is updated optimistically; the engine confirms (or corrects)
  /// through a `VolumeChangedEvent`.
  Future<void> setVolume(int volume) {
    final clamped = volume.clamp(0, 100);
    value = value.copyWith(volume: clamped);
    return _impl.enqueue(YoutubeCommand('setVolume', {'volume': clamped}));
  }

  /// Mutes the player. [value] is updated optimistically.
  Future<void> mute() {
    value = value.copyWith(isMuted: true);
    return _impl.enqueue(const YoutubeCommand('mute'));
  }

  /// Unmutes the player. [value] is updated optimistically.
  Future<void> unMute() {
    value = value.copyWith(isMuted: false);
    return _impl.enqueue(const YoutubeCommand('unMute'));
  }

  /// Sets the playback rate. Use `YoutubePlayerValue.availablePlaybackRates`
  /// (or `YoutubePlaybackRate.all`) for valid values.
  Future<void> setPlaybackRate(double rate) {
    return _impl.enqueue(YoutubeCommand('setPlaybackRate', {'rate': rate}));
  }

  /// Requests a playback quality.
  ///
  /// **Best-effort hint only**: the modern YouTube IFrame embed ignores
  /// programmatic quality selection entirely (verified against the current
  /// player — both `setPlaybackQuality` and the legacy
  /// `setPlaybackQualityRange` are no-ops server-side). YouTube selects the
  /// quality adaptively; listen to `QualityChangedEvent` for the level
  /// actually in use. The hint is still sent in case YouTube re-enables it.
  Future<void> setPlaybackQuality(YoutubeQuality quality) {
    return _impl.enqueue(
      YoutubeCommand('setPlaybackQuality', {'quality': quality.code}),
    );
  }

  /// Turns closed captions on or off. [value] is updated optimistically.
  ///
  /// Captions only render for videos that provide (or auto-generate) a
  /// caption track; for others the toggle is a harmless no-op visually.
  Future<void> setCaptionsEnabled(bool enabled) {
    value = value.copyWith(captionsEnabled: enabled);
    return _impl.enqueue(
      YoutubeCommand('setCaptionsEnabled', {'enabled': enabled}),
    );
  }

  /// Toggles closed captions.
  Future<void> toggleCaptions() => setCaptionsEnabled(!value.captionsEnabled);

  /// Enters Flutter-controlled fullscreen mode.
  ///
  /// Hides the system UI and forces [portraitFullscreenOrientations] for a
  /// portrait video or [fullscreenOrientations] otherwise on mobile,
  /// then updates [value] and emits a [FullscreenChangedEvent]. The hosting
  /// screen is responsible for reacting to the value change by expanding
  /// the player to fill the screen (see the example app).
  Future<void> enterFullscreen() async {
    if (_isDisposed || value.isFullscreen) {
      return;
    }
    await YoutubeFullscreenManager.enter(
      orientations: isPortraitVideo
          ? portraitFullscreenOrientations
          : fullscreenOrientations,
    );
    _impl.emitFullscreenChanged(isFullscreen: true);
  }

  /// Exits Flutter-controlled fullscreen mode and restores the system UI
  /// and the supported orientations.
  Future<void> exitFullscreen() async {
    if (_isDisposed || !value.isFullscreen) {
      return;
    }
    await YoutubeFullscreenManager.exit();
    _impl.emitFullscreenChanged(isFullscreen: false);
  }

  /// Toggles between fullscreen and inline display.
  Future<void> toggleFullscreen() {
    return value.isFullscreen ? exitFullscreen() : enterFullscreen();
  }

  @override
  void dispose() {
    if (_isDisposed) {
      return;
    }
    _isDisposed = true;
    _impl.dispose();
    super.dispose();
  }

  static double _seconds(Duration duration) {
    return duration.inMilliseconds / Duration.millisecondsPerSecond;
  }
}
