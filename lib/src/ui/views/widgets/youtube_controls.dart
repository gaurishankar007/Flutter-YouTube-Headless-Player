import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:youtube_headless_player/src/ui/controllers/youtube_player_controller.dart';
import 'package:youtube_headless_player/src/ui/models/youtube_progress_bar_colors.dart';
import 'package:youtube_headless_player/src/ui/views/widgets/youtube_captions_button.dart';
import 'package:youtube_headless_player/src/ui/views/widgets/youtube_error_banner.dart';
import 'package:youtube_headless_player/src/ui/views/widgets/youtube_fullscreen_button.dart';
import 'package:youtube_headless_player/src/ui/views/widgets/youtube_gesture_detector.dart';
import 'package:youtube_headless_player/src/ui/views/widgets/youtube_play_pause_button.dart';
import 'package:youtube_headless_player/src/ui/views/widgets/youtube_progress_bar.dart';
import 'package:youtube_headless_player/src/ui/views/widgets/youtube_quality_menu.dart';
import 'package:youtube_headless_player/src/ui/views/widgets/youtube_speed_menu.dart';
import 'package:youtube_headless_player/src/ui/views/widgets/youtube_time_label.dart';
import 'package:youtube_headless_player/src/ui/views/widgets/youtube_volume_slider.dart';

/// A complete, YouTube-style control overlay rendered entirely by Flutter.
///
/// Stack it on top of a `YoutubePlayer`:
///
/// ```dart
/// Stack(
///   children: [
///     YoutubePlayer(controller: controller),
///     Positioned.fill(child: YoutubeControls(controller: controller)),
///   ],
/// )
/// ```
///
/// Features: tap-to-play/pause on the video surface, auto-hiding bars
/// that reappear on mouse hover (web/desktop), center play/replay button,
/// buffering indicator, scrubbable progress bar, volume slider, playback
/// speed and quality menus, fullscreen toggle, double-tap seeking and
/// keyboard shortcuts (space/`k` play-pause, `j`/`l`/arrows seek, `m`
/// mute, `f` fullscreen, `0`–`9` percentage jump).
class YoutubeControls extends StatefulWidget {
  /// Creates the control overlay bound to [controller].
  const YoutubeControls({
    required this.controller,
    this.seekStep = const Duration(seconds: 10),
    this.autoHideDuration = const Duration(seconds: 4),
    this.enableKeyboardShortcuts = true,
    this.enableDoubleTapGestures = true,
    this.showVolumeSlider = kIsWeb,
    this.showBottomPlayPauseButton = kIsWeb,
    this.showCaptionsButton = true,
    this.showSpeedMenu = true,
    this.showQualityMenu = false,
    this.showFullscreenButton = true,
    this.progressBarColors = const YoutubeProgressBarColors(),
    super.key,
  });

  /// The controller the controls act on.
  final YoutubePlayerController controller;

  /// Amount seeked by double taps and arrow keys.
  final Duration seekStep;

  /// Idle time after which the controls hide while playing.
  final Duration autoHideDuration;

  /// Whether keyboard shortcuts are handled (desktop/web).
  final bool enableKeyboardShortcuts;

  /// Whether double-tap seek and double-tap play/pause are enabled.
  final bool enableDoubleTapGestures;

  /// Whether the volume control is shown in the bottom bar.
  ///
  /// Defaults to web only: on Android/iOS volume belongs to the hardware
  /// buttons (like the YouTube mobile app), so no button is rendered there.
  final bool showVolumeSlider;

  /// Whether a play/pause button is shown in the bottom bar (below the
  /// progress bar).
  ///
  /// Defaults to web only: on Android/iOS the centered play/pause button
  /// is the sole toggle, like the YouTube mobile app.
  final bool showBottomPlayPauseButton;

  /// Whether the closed-captions toggle is shown.
  final bool showCaptionsButton;

  /// Whether the playback speed menu is shown.
  final bool showSpeedMenu;

  /// Whether the quality menu is shown.
  ///
  /// Disabled by default: the modern YouTube IFrame embed **ignores**
  /// programmatic quality selection (`setPlaybackQuality` and the legacy
  /// `setPlaybackQualityRange` are no-ops server-side), so the menu cannot
  /// actually change the stream. Quality is chosen adaptively by YouTube;
  /// the *current* quality is still reported through
  /// `QualityChangedEvent` / `YoutubePlayerValue.quality`. Enable this only
  /// if you want the best-effort hint menu regardless.
  final bool showQualityMenu;

  /// Whether the fullscreen toggle is shown.
  final bool showFullscreenButton;

  /// Colors of the embedded [YoutubeProgressBar].
  final YoutubeProgressBarColors progressBarColors;

  @override
  State<YoutubeControls> createState() => _YoutubeControlsState();
}

class _YoutubeControlsState extends State<YoutubeControls> {
  static const Duration _fadeDuration = Duration(milliseconds: 200);
  static const double _centerButtonSize = 56;
  static const double _scrimOpacity = 0.4;
  static const int _volumeKeyStep = 10;

  /// Hit-test height of the seek bar inside the bottom bar (slimmer than
  /// the widget default, keeping the bar close to the buttons below it).
  static const double _progressBarHeight = 14;

  /// Gap between the volume control and the time label.
  static const double _timeLabelGap = 8;

  bool _visible = true;
  bool _scrubbing = false;
  bool _wasReady = false;
  Timer? _hideTimer;

  YoutubePlayerController get _controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _wasReady = _controller.value.isReady;
    _controller.addListener(_handleValueChanged);
    if (_wasReady) {
      _restartHideTimer();
    }
  }

  @override
  void didUpdateWidget(YoutubeControls oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_handleValueChanged);
      widget.controller.addListener(_handleValueChanged);
      _wasReady = widget.controller.value.isReady;
    }
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _controller.removeListener(_handleValueChanged);
    super.dispose();
  }

  void _handleValueChanged() {
    final isReady = _controller.value.isReady;
    if (isReady && !_wasReady) {
      // The player just became ready: start the auto-hide countdown so
      // the initial controls fade away on their own, exactly like any
      // other period of inactivity.
      _restartHideTimer();
    }
    _wasReady = isReady;
  }

  void _restartHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(widget.autoHideDuration, () {
      if (mounted && !_scrubbing) {
        setState(() => _visible = false);
      }
    });
  }

  void _showControls() {
    if (!_visible) {
      setState(() => _visible = true);
    }
    _restartHideTimer();
  }

  /// Shows the controls if hidden, or hides them if shown, without
  /// affecting playback. Used for the mobile tap-on-surface gesture, where
  /// play/pause is reserved for the dedicated button.
  void _toggleControlsVisibility() {
    if (_visible) {
      _hideTimer?.cancel();
      setState(() => _visible = false);
    } else {
      _showControls();
    }
  }

  bool get _isMobile =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android);

  /// Handles a single tap on any empty part of the player — the video
  /// surface itself or the blank space around the bottom bar's controls.
  ///
  /// On mobile this only shows/hides the controls (play/pause stays on the
  /// dedicated button); on web it always toggles play/pause, like the
  /// YouTube web player.
  void _handleSurfaceTap() {
    if (_isMobile) {
      _toggleControlsVisibility();
    } else {
      _togglePlayPause();
    }
  }

  /// Postpones auto-hide while the user is interacting with the overlay
  /// (pointer down/move), so slider drags and scrubbing keep the controls
  /// on screen.
  void _keepControlsAlive() {
    if (_visible) {
      _restartHideTimer();
    }
  }

  void _togglePlayPause() {
    _showControls();
    final value = _controller.value;
    if (value.hasEnded) {
      unawaited(_controller.replay());
    } else if (value.isPlaying) {
      unawaited(_controller.pause());
    } else {
      unawaited(_controller.play());
    }
  }

  void _seekBy(Duration offset) {
    _showControls();
    final value = _controller.value;
    final target = value.position + offset;
    final clamped = target < Duration.zero
        ? Duration.zero
        : (target > value.duration ? value.duration : target);
    unawaited(_controller.seekTo(clamped));
  }

  void _seekToFraction(double fraction) {
    final duration = _controller.value.duration;
    if (duration > Duration.zero) {
      _showControls();
      unawaited(_controller.seekTo(duration * fraction));
    }
  }

  void _changeVolumeBy(int delta) {
    _showControls();
    unawaited(_controller.setVolume(_controller.value.volume + delta));
  }

  void _toggleMute() {
    _showControls();
    if (_controller.value.isMuted) {
      unawaited(_controller.unMute());
    } else {
      unawaited(_controller.mute());
    }
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.space || key == LogicalKeyboardKey.keyK) {
      _togglePlayPause();
    } else if (key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.keyJ) {
      _seekBy(-widget.seekStep);
    } else if (key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.keyL) {
      _seekBy(widget.seekStep);
    } else if (key == LogicalKeyboardKey.arrowUp) {
      _changeVolumeBy(_volumeKeyStep);
    } else if (key == LogicalKeyboardKey.arrowDown) {
      _changeVolumeBy(-_volumeKeyStep);
    } else if (key == LogicalKeyboardKey.keyM) {
      _toggleMute();
    } else if (key == LogicalKeyboardKey.keyF) {
      _showControls();
      unawaited(_controller.toggleFullscreen());
    } else if (key.keyLabel.length == 1 &&
        key.keyLabel.codeUnitAt(0) >= '0'.codeUnitAt(0) &&
        key.keyLabel.codeUnitAt(0) <= '9'.codeUnitAt(0)) {
      final digit = key.keyLabel.codeUnitAt(0) - '0'.codeUnitAt(0);
      _seekToFraction(digit / 10);
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: widget.enableKeyboardShortcuts,
      onKeyEvent: widget.enableKeyboardShortcuts ? _handleKeyEvent : null,
      child: _buildInteractionKeepAlive(),
    );
  }

  /// Any pointer activity over the overlay counts as interaction and
  /// restarts the auto-hide countdown.
  Widget _buildInteractionKeepAlive() {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _keepControlsAlive(),
      onPointerMove: (_) => _keepControlsAlive(),
      // Hover events only exist for mice: moving the pointer over the
      // player reveals the controls, like the YouTube web player.
      onPointerHover: (_) => _showControls(),
      child: _buildOverlay(),
    );
  }

  Widget _buildOverlay() {
    return ValueListenableBuilder(
      valueListenable: _controller,
      builder: (context, value, _) {
        final showChrome = _visible;
        // An autoplaying video — the initial load, or a later
        // `loadVideo`/`loadNewVideo` call, which always autoplays — can sit
        // in a non-buffering, non-playing state (unknown/unstarted) for a
        // moment, which otherwise looks identical to a user-paused video.
        // Treat that window as loading too, until it either starts playing
        // or surfaces an error.
        final isLoading =
            !value.isReady ||
            value.isBuffering ||
            (value.isPendingAutoplay && !value.hasError);

        return YoutubeGestureDetector(
          onTap: _handleSurfaceTap,
          seekStep: widget.seekStep,
          onDoubleTapBackward: widget.enableDoubleTapGestures
              ? () => _seekBy(-widget.seekStep)
              : null,
          onDoubleTapForward: widget.enableDoubleTapGestures
              ? () => _seekBy(widget.seekStep)
              : null,
          // Double-tap-to-play/pause in the center zone is a deliberate,
          // dedicated gesture on every platform, unlike the single tap.
          onDoubleTapCenter: widget.enableDoubleTapGestures
              ? _togglePlayPause
              : null,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // The loading indicator stays visible even while the rest
              // of the chrome is auto-hidden.
              if (isLoading)
                const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              AnimatedOpacity(
                opacity: showChrome ? 1 : 0,
                duration: _fadeDuration,
                child: IgnorePointer(
                  ignoring: !showChrome,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ColoredBox(
                        color: Colors.black.withValues(alpha: _scrimOpacity),
                      ),
                      if (!isLoading)
                        Center(
                          child: YoutubePlayPauseButton(
                            controller: _controller,
                            iconSize: _centerButtonSize,
                            onPressed: _togglePlayPause,
                          ),
                        ),
                      if (value.hasError)
                        YoutubeErrorBanner(message: value.errorMessage),
                      Align(
                        alignment: Alignment.bottomCenter,
                        child: _buildBottomBar(),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBottomBar() {
    // System insets (home indicator, gesture bar, notch) only matter in
    // fullscreen, where the control bar meets the physical screen edge.
    // An inline player must not inherit the device's bottom inset — it
    // shows up as a large dead gap under the controls.
    final avoidSystemInsets = _controller.value.isFullscreen;
    // Claims taps over the whole control bar, including the empty gaps
    // between buttons, so a tap there behaves like tapping the rest of the
    // surface (see `_handleSurfaceTap`) instead of falling through to the
    // double-tap seek zones underneath. Individual buttons still win the
    // gesture arena over this wrapper since they sit deeper in the tree.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _handleSurfaceTap,
      onDoubleTap: () {},
      child: SafeArea(
        top: false,
        left: avoidSystemInsets,
        right: avoidSystemInsets,
        bottom: avoidSystemInsets,
        child: Padding(
          // No bottom padding: the buttons' own tap-target padding already
          // provides the visual breathing room, so the bar hugs the
          // bottom edge of the player like the YouTube control bar.
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              YoutubeProgressBar(
                controller: _controller,
                colors: widget.progressBarColors,
                // Slimmer than the widget default so the seek bar hugs the
                // button row underneath, like the YouTube control bar.
                height: _progressBarHeight,
                onDragStart: () {
                  _scrubbing = true;
                  _showControls();
                },
                onDragEnd: () {
                  _scrubbing = false;
                  _restartHideTimer();
                },
              ),
              Row(
                children: [
                  if (widget.showBottomPlayPauseButton)
                    YoutubePlayPauseButton(
                      controller: _controller,
                      onPressed: _togglePlayPause,
                    ),
                  if (widget.showVolumeSlider) ...[
                    YoutubeVolumeSlider(controller: _controller),
                    const SizedBox(width: _timeLabelGap),
                  ],
                  YoutubeTimeLabel(controller: _controller),
                  const Spacer(),
                  if (widget.showCaptionsButton)
                    YoutubeCaptionsButton(controller: _controller),
                  if (widget.showSpeedMenu)
                    YoutubeSpeedMenu(controller: _controller),
                  if (widget.showQualityMenu)
                    YoutubeQualityMenu(controller: _controller),
                  if (widget.showFullscreenButton)
                    YoutubeFullscreenButton(controller: _controller),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
