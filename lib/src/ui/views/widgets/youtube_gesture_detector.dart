import 'dart:async';

import 'package:material_ui/material_ui.dart';

/// Zones a double tap can land in.
enum _GestureZone { backward, center, forward }

/// Full-surface gesture layer for the player.
///
/// - Single tap → [onTap] (toggles play/pause on web; on mobile just
///   shows/hides the controls, since callers reserve play/pause there for
///   a dedicated button).
/// - Double tap on the left/right third → [onDoubleTapBackward] /
///   [onDoubleTapForward] (seek), with an animated skip indicator.
/// - Double tap in the middle → [onDoubleTapCenter] (play/pause).
class YoutubeGestureDetector extends StatefulWidget {
  /// Creates the gesture layer.
  const YoutubeGestureDetector({
    this.onTap,
    this.onDoubleTapBackward,
    this.onDoubleTapForward,
    this.onDoubleTapCenter,
    this.seekStep = const Duration(seconds: 10),
    this.child,
    super.key,
  });

  /// Called on a single tap anywhere on the surface.
  final VoidCallback? onTap;

  /// Called on a double tap over the left zone.
  final VoidCallback? onDoubleTapBackward;

  /// Called on a double tap over the right zone.
  final VoidCallback? onDoubleTapForward;

  /// Called on a double tap over the center zone.
  final VoidCallback? onDoubleTapCenter;

  /// Seek amount shown by the skip indicators.
  final Duration seekStep;

  /// Optional content rendered underneath the gesture surface.
  final Widget? child;

  @override
  State<YoutubeGestureDetector> createState() => _YoutubeGestureDetectorState();
}

class _YoutubeGestureDetectorState extends State<YoutubeGestureDetector> {
  /// Fraction of the width belonging to each side zone.
  static const double _sideZoneFraction = 0.35;

  /// How long the skip indicator stays visible after a double tap.
  static const Duration _feedbackDuration = Duration(milliseconds: 600);

  static const double _feedbackIconSize = 40;
  static const double _feedbackHorizontalInset = 32;

  Offset? _lastDoubleTapPosition;
  _GestureZone? _feedbackZone;
  Timer? _feedbackTimer;

  @override
  void dispose() {
    _feedbackTimer?.cancel();
    super.dispose();
  }

  void _handleDoubleTap() {
    final position = _lastDoubleTapPosition;
    final width = context.size?.width;
    if (position == null || width == null || width <= 0) {
      return;
    }
    final zone = switch (position.dx / width) {
      < _sideZoneFraction => _GestureZone.backward,
      > 1 - _sideZoneFraction => _GestureZone.forward,
      _ => _GestureZone.center,
    };
    switch (zone) {
      case _GestureZone.backward:
        if (widget.onDoubleTapBackward == null) {
          return;
        }
        widget.onDoubleTapBackward!();
      case _GestureZone.forward:
        if (widget.onDoubleTapForward == null) {
          return;
        }
        widget.onDoubleTapForward!();
      case _GestureZone.center:
        widget.onDoubleTapCenter?.call();
        return;
    }
    _showFeedback(zone);
  }

  void _showFeedback(_GestureZone zone) {
    _feedbackTimer?.cancel();
    setState(() => _feedbackZone = zone);
    _feedbackTimer = Timer(_feedbackDuration, () {
      if (mounted) {
        setState(() => _feedbackZone = null);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onDoubleTapDown: (details) =>
          _lastDoubleTapPosition = details.localPosition,
      onDoubleTap: _handleDoubleTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (widget.child != null) widget.child!,
          _SeekFeedback(
            visible: _feedbackZone == _GestureZone.backward,
            alignment: Alignment.centerLeft,
            icon: Icons.fast_rewind_rounded,
            seconds: widget.seekStep.inSeconds,
          ),
          _SeekFeedback(
            visible: _feedbackZone == _GestureZone.forward,
            alignment: Alignment.centerRight,
            icon: Icons.fast_forward_rounded,
            seconds: widget.seekStep.inSeconds,
          ),
        ],
      ),
    );
  }
}

/// The transient "±N seconds" indicator flashed after a double-tap seek.
class _SeekFeedback extends StatelessWidget {
  const _SeekFeedback({
    required this.visible,
    required this.alignment,
    required this.icon,
    required this.seconds,
  });

  static const Duration _fadeDuration = Duration(milliseconds: 150);

  final bool visible;
  final Alignment alignment;
  final IconData icon;
  final int seconds;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Align(
        alignment: alignment,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: _YoutubeGestureDetectorState._feedbackHorizontalInset,
          ),
          child: AnimatedOpacity(
            opacity: visible ? 1 : 0,
            duration: _fadeDuration,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  color: Colors.white,
                  size: _YoutubeGestureDetectorState._feedbackIconSize,
                ),
                Text('$seconds s', style: const TextStyle(color: Colors.white)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
