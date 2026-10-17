import 'package:flutter/foundation.dart';
import 'package:youtube_headless_player/src/data/services/youtube_engine_transport.dart';
import 'package:youtube_headless_player/src/domain/models/youtube_player_event.dart';
import 'package:youtube_headless_player/src/domain/models/youtube_quality.dart';

/// A single JSON command sent from Flutter to the JavaScript engine.
///
/// Commands are dispatched through one JavaScript entry point
/// (`window.youtubeHeadlessPlayer.dispatch(...)`), so no raw JavaScript is
/// generated per action anywhere in the package.
@internal
@immutable
class const YoutubeCommand(
  /// The action identifier understood by the JavaScript dispatcher.
  final String action, [

  /// Additional parameters merged into the command payload.
  final Map<String, Object?> params = const {},
]) {
  /// Creates a command with an [action] name and optional [params].
  this;

  /// The JSON payload sent over the bridge.
  Map<String, Object?> toJson() => {'action': action, ...params};
}

/// Bidirectional bridge between Dart and the JavaScript playback engine.
///
/// Independent of how the engine is hosted:
/// - Flutter → JavaScript: [send] hands a [YoutubeCommand]'s JSON payload to
///   the attached [YoutubeEngineTransport].
/// - JavaScript → Flutter: the engine view passes every structured JSON
///   payload to [receive], which decodes it into a typed
///   [YoutubePlayerEvent].
@internal
class YoutubeBridge {
  static int _instanceCount = 0;

  /// Unique id of this bridge instance.
  ///
  /// On web it is passed to the engine document as a query parameter and
  /// echoed back in every `postMessage` event, so multiple players on one
  /// page never receive each other's events.
  final String playerId = 'ytp${_instanceCount++}';

  YoutubeEngineTransport? _transport;
  ValueChanged<YoutubePlayerEvent>? _onEvent;
  VoidCallback? _onPageReady;

  /// Whether an engine is currently attached.
  bool get isAttached => _transport != null;

  /// Attaches the bridge to a freshly created engine and starts routing its
  /// events to [onEvent].
  ///
  /// [onPageReady] fires on every `pageReady` announcement the engine emits
  /// while waiting to be initialized; the owner responds by (re-)sending the
  /// idempotent `initialize` command, which makes startup immune to races
  /// between page load callbacks and script evaluation.
  void attach(
    YoutubeEngineTransport transport, {
    required ValueChanged<YoutubePlayerEvent> onEvent,
    required VoidCallback onPageReady,
  }) {
    _transport = transport;
    _onEvent = onEvent;
    _onPageReady = onPageReady;
  }

  /// Detaches the bridge from the engine (e.g. when the engine view is
  /// removed from the tree). Pending [send] calls become no-ops.
  void detach() {
    _transport = null;
    _onEvent = null;
    _onPageReady = null;
  }

  /// Handles a JSON [payload] posted by the engine.
  void receive(Map<String, Object?> payload) {
    if (payload['event'] == 'pageReady') {
      _onPageReady?.call();
      return;
    }
    final event = decodeEvent(payload);
    if (event != null) {
      _onEvent?.call(event);
    }
  }

  /// Sends a [command] to the JavaScript dispatcher.
  Future<void> send(YoutubeCommand command) async {
    await _transport?.dispatch(command.toJson());
  }

  /// Decodes a structured JSON event coming from `player.js` into a typed
  /// [YoutubePlayerEvent]. Returns `null` for unknown event names.
  @visibleForTesting
  static YoutubePlayerEvent? decodeEvent(Map<String, Object?> payload) {
    return switch (payload['event']) {
      'ready' => ReadyEvent(
        duration: _duration(payload['duration']),
        volume: _int(payload['volume'], fallback: 100),
        isMuted: payload['muted'] == true,
        playbackRate: _double(payload['rate'], fallback: 1),
        availablePlaybackRates: _doubleList(payload['availableRates']),
        availableQualities: _qualityList(payload['availableQualities']),
      ),
      'playing' => const PlayingEvent(),
      'paused' => const PausedEvent(),
      'buffering' => const BufferingEvent(),
      'ended' => const EndedEvent(),
      'idle' => const IdleEvent(),
      'progress' => ProgressEvent(
        position: _duration(payload['position']),
        duration: _duration(payload['duration']),
        bufferedFraction: _double(payload['buffered'], fallback: 0),
      ),
      'durationChanged' => DurationChangedEvent(
        duration: _duration(payload['duration']),
      ),
      'qualityChanged' => QualityChangedEvent(
        quality: .fromCode(payload['quality'] as String?),
        availableQualities: _qualityList(payload['availableQualities']),
      ),
      'playbackRateChanged' => PlaybackRateChangedEvent(
        playbackRate: _double(payload['rate'], fallback: 1),
      ),
      'volumeChanged' => VolumeChangedEvent(
        volume: _int(payload['volume'], fallback: 100),
        isMuted: payload['muted'] == true,
      ),
      'captionsChanged' => CaptionsChangedEvent(
        isEnabled: payload['enabled'] == true,
      ),
      'error' => ErrorEvent(
        code: _int(payload['code'], fallback: -1),
        message: payload['message'] as String? ?? 'Unknown player error.',
      ),
      'videoLoaded' => VideoLoadedEvent(
        videoId: payload['videoId'] as String? ?? '',
      ),
      'videoCued' => VideoCuedEvent(videoId: payload['videoId'] as String?),
      _ => null,
    };
  }

  static Duration _duration(Object? seconds) {
    final value = _double(seconds, fallback: 0);
    return Duration(
      milliseconds: (value * Duration.millisecondsPerSecond).round(),
    );
  }

  static double _double(Object? value, {required double fallback}) {
    return value is num ? value.toDouble() : fallback;
  }

  static int _int(Object? value, {required int fallback}) {
    return value is num ? value.round() : fallback;
  }

  static List<double> _doubleList(Object? value) {
    if (value is! List) {
      return const [];
    }
    return value.whereType<num>().map((rate) => rate.toDouble()).toList();
  }

  static List<YoutubeQuality> _qualityList(Object? value) {
    if (value is! List) {
      return const [];
    }
    // `toSet` dedups: unknown wire codes all collapse into `auto`.
    return value
        .whereType<String>()
        .map(YoutubeQuality.fromCode)
        .toSet()
        .toList();
  }
}
