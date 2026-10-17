import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:youtube_headless_player/src/data/services/platform/youtube_web_events_stub.dart'
    if (dart.library.js_interop) 'package:youtube_headless_player/src/data/services/platform/youtube_web_events_web.dart';
import 'package:youtube_headless_player/src/domain/models/youtube_player_event.dart';
import 'package:youtube_headless_player/src/domain/models/youtube_quality.dart';

/// A single JSON command sent from Flutter to the JavaScript engine.
///
/// Commands are dispatched through one JavaScript entry point
/// (`window.youtubeHeadlessPlayer.dispatch(...)`), so no raw JavaScript is
/// generated per action anywhere else in the package.
@internal
@immutable
class YoutubeCommand {
  /// Creates a command with an [action] name and optional [params].
  const YoutubeCommand(this.action, [this.params = const {}]);

  /// The action identifier understood by the JavaScript dispatcher.
  final String action;

  /// Additional parameters merged into the command payload.
  final Map<String, Object?> params;

  /// The JSON payload sent over the bridge.
  Map<String, Object?> toJson() => {'action': action, ...params};
}

/// Bidirectional bridge between Dart and the JavaScript playback engine.
///
/// - Flutter → JavaScript: [send] serializes a [YoutubeCommand] to JSON and
///   evaluates a single `dispatch` call.
/// - JavaScript → Flutter: a `callHandler` channel delivers structured JSON
///   events, which are decoded into typed [YoutubePlayerEvent]s.
@internal
class YoutubeBridge {
  /// Name of the JavaScript handler the engine posts events to. Must match
  /// `EVENT_CHANNEL` in `assets/youtube/player.js`.
  static const String eventChannelName = 'YoutubePlayerEvents';

  static int _instanceCount = 0;

  /// Unique id of this bridge instance.
  ///
  /// On web it is passed to the engine document as a query parameter and
  /// echoed back in every `postMessage` event, so multiple players on one
  /// page never receive each other's events.
  final String playerId = 'ytp${_instanceCount++}';

  InAppWebViewController? _webViewController;

  /// Whether a WebView is currently attached.
  bool get isAttached => _webViewController != null;

  /// Attaches the bridge to a freshly created WebView and starts routing
  /// engine events to [onEvent].
  ///
  /// [onPageReady] fires on every `pageReady` announcement the engine emits
  /// while waiting to be initialized; the owner responds by (re-)sending the
  /// idempotent `initialize` command, which makes startup immune to races
  /// between page load callbacks and script evaluation.
  ///
  /// `player.js` prefers `window.flutter_inappwebview.callHandler` whenever
  /// it exists and only falls back to posting a `message` to the parent
  /// window otherwise. The bundled `flutter_inappwebview_web` version
  /// injects a working `callHandler` shim into the iframe on Flutter Web
  /// too (same-origin, javascript bridge enabled by default), so the
  /// JavaScript handler is registered on every platform here - registering
  /// it only for non-web would silently lose every event on web, since
  /// `player.js` would keep calling a handler nothing is listening for and
  /// never fall through to `postMessage`. The `message` listener stays
  /// registered on web too as a fallback for setups where the shim isn't
  /// available (e.g. a cross-origin iframe, or an older package version).
  void attach(
    InAppWebViewController webViewController, {
    required ValueChanged<YoutubePlayerEvent> onEvent,
    required VoidCallback onPageReady,
  }) {
    _webViewController = webViewController;
    void handlePayload(Map<String, Object?> payload) {
      if (payload['event'] == 'pageReady') {
        onPageReady();
        return;
      }
      final event = decodeEvent(payload);
      if (event != null) {
        onEvent(event);
      }
    }

    if (kIsWeb) {
      registerYoutubeWebEventListener(playerId, handlePayload);
    }
    webViewController.addJavaScriptHandler(
      handlerName: eventChannelName,
      callback: (arguments) {
        final payload = arguments.isNotEmpty ? arguments.first : null;
        if (payload is Map) {
          handlePayload(Map<String, Object?>.from(payload));
        }
        return null;
      },
    );
  }

  /// Detaches the bridge from the WebView (e.g. when the widget is removed
  /// from the tree). Pending [send] calls become no-ops.
  void detach() {
    if (kIsWeb) {
      unregisterYoutubeWebEventListener(playerId);
    }
    _webViewController = null;
  }

  /// Sends a [command] to the JavaScript dispatcher and returns its result
  /// (used by getter-style commands; `null` for fire-and-forget actions).
  Future<Object?> send(YoutubeCommand command) async {
    final webViewController = _webViewController;
    if (webViewController == null) {
      return null;
    }
    // `jsonEncode` output is a valid JavaScript object literal, so the
    // command travels as data — never as interpolated code fragments.
    final payload = jsonEncode(command.toJson());
    return webViewController.evaluateJavascript(
      source:
          'window.youtubeHeadlessPlayer && window.youtubeHeadlessPlayer.dispatch($payload)',
    );
  }

  /// Decodes a structured JSON event coming from `player.js` into a typed
  /// [YoutubePlayerEvent]. Returns `null` for unknown event names.
  @visibleForTesting
  static YoutubePlayerEvent? decodeEvent(Map<String, Object?> payload) {
    switch (payload['event']) {
      case 'ready':
        return ReadyEvent(
          duration: _duration(payload['duration']),
          volume: _int(payload['volume'], fallback: 100),
          isMuted: payload['muted'] == true,
          playbackRate: _double(payload['rate'], fallback: 1),
          availablePlaybackRates: _doubleList(payload['availableRates']),
          availableQualities: _qualityList(payload['availableQualities']),
        );
      case 'playing':
        return const PlayingEvent();
      case 'paused':
        return const PausedEvent();
      case 'buffering':
        return const BufferingEvent();
      case 'ended':
        return const EndedEvent();
      case 'idle':
        return const IdleEvent();
      case 'progress':
        return ProgressEvent(
          position: _duration(payload['position']),
          duration: _duration(payload['duration']),
          bufferedFraction: _double(payload['buffered'], fallback: 0),
        );
      case 'durationChanged':
        return DurationChangedEvent(duration: _duration(payload['duration']));
      case 'qualityChanged':
        return QualityChangedEvent(
          quality: YoutubeQuality.fromCode(payload['quality'] as String?),
          availableQualities: _qualityList(payload['availableQualities']),
        );
      case 'playbackRateChanged':
        return PlaybackRateChangedEvent(
          playbackRate: _double(payload['rate'], fallback: 1),
        );
      case 'volumeChanged':
        return VolumeChangedEvent(
          volume: _int(payload['volume'], fallback: 100),
          isMuted: payload['muted'] == true,
        );
      case 'captionsChanged':
        return CaptionsChangedEvent(isEnabled: payload['enabled'] == true);
      case 'error':
        return ErrorEvent(
          code: _int(payload['code'], fallback: -1),
          message: payload['message'] as String? ?? 'Unknown player error.',
        );
      case 'videoLoaded':
        return VideoLoadedEvent(videoId: payload['videoId'] as String? ?? '');
      case 'videoCued':
        return VideoCuedEvent(videoId: payload['videoId'] as String?);
      default:
        return null;
    }
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
