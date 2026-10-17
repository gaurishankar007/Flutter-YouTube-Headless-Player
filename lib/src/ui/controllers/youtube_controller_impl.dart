import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:meta/meta.dart';
import 'package:youtube_headless_player/src/data/services/youtube_bridge.dart';
import 'package:youtube_headless_player/src/domain/models/youtube_player_event.dart';
import 'package:youtube_headless_player/src/domain/models/youtube_player_state.dart';
import 'package:youtube_headless_player/src/domain/models/youtube_player_value.dart';
import 'package:youtube_headless_player/src/ui/controllers/youtube_player_controller.dart';

/// Internal engine-facing half of [YoutubePlayerController].
///
/// Owns the JavaScript bridge, the typed event stream, and the queue of
/// commands issued before the player becomes ready. The public controller
/// delegates every playback command here; the WebView host widget attaches
/// and detaches the underlying [InAppWebViewController].
@internal
class YoutubeControllerImpl {
  /// Creates the implementation backing [controller].
  YoutubeControllerImpl({required this.controller});

  /// Reported positions within this distance of a pending seek target are
  /// considered "the seek has landed".
  static const Duration _seekSettleTolerance = Duration(seconds: 2);

  /// A pending seek is abandoned after this long, whatever the engine says.
  static const Duration _seekSettleTimeout = Duration(seconds: 5);

  /// The public controller whose [YoutubePlayerValue] this class mutates.
  final YoutubePlayerController controller;

  final YoutubeBridge _bridge = YoutubeBridge();
  final StreamController<YoutubePlayerEvent> _eventController =
      StreamController<YoutubePlayerEvent>.broadcast();
  final List<YoutubeCommand> _pendingCommands = [];
  final Stopwatch _seekStopwatch = Stopwatch();
  Duration? _pendingSeekTarget;
  bool _isDisposed = false;

  /// Typed events emitted by the player, in arrival order.
  Stream<YoutubePlayerEvent> get events => _eventController.stream;

  /// Unique id of the underlying bridge (used as the `playerId` query
  /// parameter of the engine document on web).
  String get playerId => _bridge.playerId;

  /// Connects the bridge to a freshly created WebView.
  ///
  /// Called by the WebView host from `onWebViewCreated`.
  void attachWebView(InAppWebViewController webViewController) {
    if (_isDisposed) {
      return;
    }
    _bridge.attach(
      webViewController,
      onEvent: _handleEvent,
      onPageReady: () => unawaited(onPageLoaded()),
    );
  }

  /// Sends the `initialize` command to the JavaScript engine.
  ///
  /// Called from `onLoadStop` and from every `pageReady` announcement the
  /// engine emits before it is initialized. The command is idempotent on
  /// the JavaScript side, so duplicate sends are harmless.
  Future<void> onPageLoaded() async {
    if (_isDisposed) {
      return;
    }
    await _bridge.send(YoutubeCommand('initialize', _initializeParams()));
  }

  /// Disconnects the bridge when the WebView leaves the tree.
  ///
  /// Called from the WebView host's `dispose`, which can run while the
  /// element tree is locked (e.g. the subtree is being unmounted during a
  /// fullscreen layout swap). Notifying listeners synchronously there makes
  /// `ValueListenableBuilder`s call `markNeedsBuild` inside the locked
  /// phase and crash, so the value update is deferred when a frame is in
  /// flight.
  void detachWebView() {
    _bridge.detach();
    _clearPendingSeek();
    if (_isDisposed) {
      return;
    }
    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.idle) {
      controller.value = controller.value.copyWith(isReady: false);
      return;
    }
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!_isDisposed) {
        controller.value = controller.value.copyWith(isReady: false);
      }
    });
  }

  /// Registers an in-flight seek and applies it to [controller] optimistically.
  ///
  /// The engine keeps reporting the pre-seek position for a few progress
  /// ticks (the IFrame proxy applies commands asynchronously), so the
  /// target is latched: progress events cannot move the position until the
  /// reported position lands near the target — matching how the real
  /// YouTube scrubber behaves while a seek is loading.
  void registerSeek(Duration target) {
    if (_isDisposed) {
      return;
    }
    _pendingSeekTarget = target;
    _seekStopwatch
      ..reset()
      ..start();
    controller.value = controller.value.copyWith(position: target);
  }

  void _clearPendingSeek() {
    _pendingSeekTarget = null;
    _seekStopwatch
      ..stop()
      ..reset();
  }

  /// Sends a command now, or queues it until the player reports readiness.
  Future<void> enqueue(YoutubeCommand command) async {
    if (_isDisposed) {
      return;
    }
    if (!controller.value.isReady || !_bridge.isAttached) {
      _pendingCommands.add(command);
      return;
    }
    await _bridge.send(command);
  }

  /// Publishes a Flutter-side fullscreen transition to value and stream.
  void emitFullscreenChanged({required bool isFullscreen}) {
    if (_isDisposed) {
      return;
    }
    controller.value = controller.value.copyWith(isFullscreen: isFullscreen);
    _eventController.add(FullscreenChangedEvent(isFullscreen: isFullscreen));
  }

  /// Destroys the JavaScript player and releases all Dart-side resources.
  void dispose() {
    if (_isDisposed) {
      return;
    }
    _isDisposed = true;
    _pendingCommands.clear();
    _clearPendingSeek();
    // Best effort: tear down the JS player if a WebView is still attached.
    unawaited(_bridge.send(const YoutubeCommand('destroy')));
    _bridge.detach();
    unawaited(_eventController.close());
  }

  /// Builds the `initialize` payload from the controller's configuration.
  Map<String, Object?> _initializeParams() {
    return {
      'videoId': controller.initialVideoId,
      'autoPlay': controller.autoPlay,
      'muted': controller.startMuted,
      'loop': controller.loop,
      if (controller.startAt != null)
        'startSeconds': _seconds(controller.startAt!),
      if (controller.endAt != null) 'endSeconds': _seconds(controller.endAt!),
      if (controller.interfaceLanguage != null)
        'interfaceLanguage': controller.interfaceLanguage,
      'captionsEnabled': controller.captionsEnabled,
      if (controller.captionsLanguage != null)
        'captionsLanguage': controller.captionsLanguage,
    };
  }

  void _handleEvent(YoutubePlayerEvent event) {
    if (_isDisposed) {
      return;
    }
    controller.value = _reduce(controller.value, event);
    _eventController.add(event);
    if (event is ReadyEvent) {
      unawaited(_flushPendingCommands());
    }
  }

  Future<void> _flushPendingCommands() async {
    while (_pendingCommands.isNotEmpty && !_isDisposed && _bridge.isAttached) {
      final command = _pendingCommands.removeAt(0);
      await _bridge.send(command);
    }
  }

  /// Folds an incoming [event] into the previous [value] snapshot.
  YoutubePlayerValue _reduce(
    YoutubePlayerValue value,
    YoutubePlayerEvent event,
  ) {
    switch (event) {
      case ReadyEvent():
        return value.copyWith(
          isReady: true,
          duration: event.duration,
          volume: event.volume,
          isMuted: event.isMuted,
          playbackRate: event.playbackRate,
          availablePlaybackRates: event.availablePlaybackRates,
          availableQualities: event.availableQualities.isNotEmpty
              ? event.availableQualities
              : null,
          isPendingAutoplay: controller.autoPlay,
        );
      case PlayingEvent():
        return value.copyWith(
          playerState: YoutubePlayerState.playing,
          isPendingAutoplay: false,
        );
      case PausedEvent():
        return value.copyWith(
          playerState: YoutubePlayerState.paused,
          isPendingAutoplay: false,
        );
      case BufferingEvent():
        return value.copyWith(playerState: YoutubePlayerState.buffering);
      case EndedEvent():
        _clearPendingSeek();
        return value.copyWith(
          playerState: YoutubePlayerState.ended,
          position: value.duration,
        );
      case IdleEvent():
        _clearPendingSeek();
        return value.copyWith(playerState: YoutubePlayerState.idle);
      case ProgressEvent():
        final pendingSeek = _pendingSeekTarget;
        if (pendingSeek != null) {
          final settled =
              (event.position - pendingSeek).abs() <= _seekSettleTolerance;
          final expired = _seekStopwatch.elapsed >= _seekSettleTimeout;
          if (!settled && !expired) {
            // Stale pre-seek positions must not move the scrubber back;
            // duration and buffering info are still worth taking.
            return value.copyWith(
              position: pendingSeek,
              duration: event.duration,
              bufferedFraction: event.bufferedFraction,
            );
          }
          _clearPendingSeek();
        }
        return value.copyWith(
          position: event.position,
          duration: event.duration,
          bufferedFraction: event.bufferedFraction,
        );
      case DurationChangedEvent():
        return value.copyWith(duration: event.duration);
      case QualityChangedEvent():
        return value.copyWith(
          quality: event.quality,
          availableQualities: event.availableQualities.isNotEmpty
              ? event.availableQualities
              : null,
        );
      case PlaybackRateChangedEvent():
        return value.copyWith(playbackRate: event.playbackRate);
      case VolumeChangedEvent():
        return value.copyWith(volume: event.volume, isMuted: event.isMuted);
      case CaptionsChangedEvent():
        return value.copyWith(captionsEnabled: event.isEnabled);
      case FullscreenChangedEvent():
        return value.copyWith(isFullscreen: event.isFullscreen);
      case VideoLoadedEvent():
        _clearPendingSeek();
        return value.copyWith(
          videoId: event.videoId,
          position: Duration.zero,
          bufferedFraction: 0,
          // `load` always autoplays, regardless of when in the player's
          // lifetime it's called.
          isPendingAutoplay: true,
        );
      case VideoCuedEvent():
        _clearPendingSeek();
        return value.copyWith(
          playerState: YoutubePlayerState.cued,
          videoId: event.videoId,
          isPendingAutoplay: false,
        );
      case ErrorEvent():
        _clearPendingSeek();
        return value.copyWith(
          errorCode: event.code,
          errorMessage: event.message,
          isPendingAutoplay: false,
        );
    }
  }

  static double _seconds(Duration duration) {
    return duration.inMilliseconds / Duration.millisecondsPerSecond;
  }
}

final Expando<YoutubeControllerImpl> _implementations =
    Expando<YoutubeControllerImpl>('YoutubeControllerImpl');

/// Resolves (creating on first access) the internal implementation bound to
/// a [controller].
///
/// Keeps the engine-facing half completely out of the public API surface:
/// both [YoutubePlayerController] and the WebView host reach it through this
/// package-private registry instead of a public member on the controller.
@internal
YoutubeControllerImpl youtubeControllerImplOf(
  YoutubePlayerController controller,
) {
  return _implementations[controller] ??= YoutubeControllerImpl(
    controller: controller,
  );
}
