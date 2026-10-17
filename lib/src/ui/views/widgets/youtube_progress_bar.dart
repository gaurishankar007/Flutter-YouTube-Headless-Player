import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:youtube_headless_player/src/ui/controllers/youtube_player_controller.dart';
import 'package:youtube_headless_player/src/ui/models/youtube_progress_bar_colors.dart';

/// A scrubbable timeline showing playback and buffer progress.
///
/// Dragging previews the target position immediately and issues a single
/// seek when the gesture ends, keeping bridge traffic minimal.
class const YoutubeProgressBar({
  /// The controller to observe and seek on.
  required final YoutubePlayerController controller,

  /// Colors of the track segments and thumb.
  final YoutubeProgressBarColors colors = const YoutubeProgressBarColors(),

  /// Total hit-test height of the bar.
  final double height = 24,

  /// Painted height of the track.
  final double trackHeight = 3,

  /// Radius of the thumb circle.
  final double thumbRadius = 6,

  /// Called when a scrub gesture starts (e.g. to pin the controls open).
  final VoidCallback? onDragStart,

  /// Called when a scrub gesture ends.
  final VoidCallback? onDragEnd,
  super.key,
}) extends StatefulWidget {
  /// Creates a progress bar bound to [controller].
  this;

  @override
  State<YoutubeProgressBar> createState() => _YoutubeProgressBarState();
}

class _YoutubeProgressBarState extends State<YoutubeProgressBar> {
  /// Preview fraction while scrubbing; `null` when not scrubbing.
  double? _dragFraction;

  /// Whether a horizontal drag gesture currently owns the scrub.
  bool _dragging = false;

  double _fractionAt(Offset localPosition, double width) {
    if (width <= 0) {
      return 0;
    }
    return (localPosition.dx / width).clamp(0.0, 1.0);
  }

  void _handleTapDown(Offset localPosition, double width) {
    widget.onDragStart?.call();
    setState(() => _dragFraction = _fractionAt(localPosition, width));
  }

  /// Seeks straight from the tap-up position.
  ///
  /// Deliberately independent of [_dragFraction]: when a tap wins the
  /// gesture arena, the losing drag recognizer's cancel callback may clear
  /// the shared preview state *before* this runs, and relying on it made
  /// taps silently fall back to the previous position.
  void _handleTapUp(Offset localPosition, double width) {
    _seekToFraction(_fractionAt(localPosition, width));
    setState(() => _dragFraction = null);
    widget.onDragEnd?.call();
  }

  void _handleTapCancel() {
    // A drag took over (or an ancestor gesture won). If a drag owns the
    // scrub its own callbacks manage the state; otherwise clean up.
    if (!_dragging) {
      setState(() => _dragFraction = null);
      widget.onDragEnd?.call();
    }
  }

  void _startDrag(Offset localPosition, double width) {
    _dragging = true;
    widget.onDragStart?.call();
    setState(() => _dragFraction = _fractionAt(localPosition, width));
  }

  void _updateDrag(Offset localPosition, double width) {
    setState(() => _dragFraction = _fractionAt(localPosition, width));
  }

  void _endDrag() {
    _dragging = false;
    final fraction = _dragFraction;
    if (fraction != null) {
      _seekToFraction(fraction);
    }
    setState(() => _dragFraction = null);
    widget.onDragEnd?.call();
  }

  void _cancelDrag() {
    _dragging = false;
    setState(() => _dragFraction = null);
    widget.onDragEnd?.call();
  }

  void _seekToFraction(double fraction) {
    final duration = widget.controller.value.duration;
    if (duration <= Duration.zero) {
      return;
    }
    unawaited(widget.controller.seekTo(duration * fraction));
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: widget.controller,
      builder: (context, value, _) {
        final durationMs = value.duration.inMilliseconds;
        final playedFraction =
            _dragFraction ??
            (durationMs > 0
                ? (value.position.inMilliseconds / durationMs).clamp(0.0, 1.0)
                : 0.0);
        return LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            return MouseRegion(
              // The whole scrub strip is clickable, so show the hand
              // cursor like the real YouTube seek bar.
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (details) =>
                    _handleTapDown(details.localPosition, width),
                onTapUp: (details) =>
                    _handleTapUp(details.localPosition, width),
                onTapCancel: _handleTapCancel,
                onHorizontalDragStart: (details) =>
                    _startDrag(details.localPosition, width),
                onHorizontalDragUpdate: (details) =>
                    _updateDrag(details.localPosition, width),
                onHorizontalDragEnd: (_) => _endDrag(),
                onHorizontalDragCancel: _cancelDrag,
                child: SizedBox(
                  height: widget.height,
                  width: double.infinity,
                  child: CustomPaint(
                    painter: _ProgressBarPainter(
                      playedFraction: playedFraction,
                      bufferedFraction: value.bufferedFraction.clamp(0.0, 1.0),
                      colors: widget.colors,
                      trackHeight: widget.trackHeight,
                      thumbRadius: widget.thumbRadius,
                      isScrubbing: _dragFraction != null,
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class const _ProgressBarPainter({
  required final double playedFraction,
  required final double bufferedFraction,
  required final YoutubeProgressBarColors colors,
  required final double trackHeight,
  required final double thumbRadius,
  required final bool isScrubbing,
}) extends CustomPainter {
  /// Extra thumb growth while scrubbing, for a subtle grab affordance.
  static const double _scrubThumbScale = 1.35;

  @override
  void paint(Canvas canvas, Size size) {
    final centerY = size.height / 2;
    final radius = Radius.circular(trackHeight / 2);
    final trackRect = Rect.fromLTWH(
      0,
      centerY - trackHeight / 2,
      size.width,
      trackHeight,
    );

    void drawSegment(double fraction, Color color) {
      if (fraction <= 0) {
        return;
      }
      final rect = Rect.fromLTWH(
        0,
        trackRect.top,
        size.width * fraction,
        trackHeight,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, radius),
        Paint()..color = color,
      );
    }

    canvas.drawRRect(
      RRect.fromRectAndRadius(trackRect, radius),
      Paint()..color = colors.background,
    );
    drawSegment(bufferedFraction, colors.buffered);
    drawSegment(playedFraction, colors.played);

    canvas.drawCircle(
      Offset(size.width * playedFraction, centerY),
      isScrubbing ? thumbRadius * _scrubThumbScale : thumbRadius,
      Paint()..color = colors.thumb,
    );
  }

  @override
  bool shouldRepaint(_ProgressBarPainter oldDelegate) {
    return playedFraction != oldDelegate.playedFraction ||
        bufferedFraction != oldDelegate.bufferedFraction ||
        isScrubbing != oldDelegate.isScrubbing ||
        colors != oldDelegate.colors;
  }
}
