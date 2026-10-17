import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:youtube_headless_player/src/ui/controllers/youtube_player_controller.dart';

/// Play / pause / replay button reflecting the controller state.
class YoutubePlayPauseButton extends StatelessWidget {
  /// Creates a play/pause button bound to [controller].
  const YoutubePlayPauseButton({
    required this.controller,
    this.iconSize = 28,
    this.color = Colors.white,
    this.onPressed,
    super.key,
  });

  /// The controller to observe and act on.
  final YoutubePlayerController controller;

  /// Icon size in logical pixels.
  final double iconSize;

  /// Icon color.
  final Color color;

  /// Overrides the default play/pause/replay behavior when provided.
  final VoidCallback? onPressed;

  void _defaultAction() {
    final value = controller.value;
    if (value.hasEnded) {
      unawaited(controller.replay());
    } else if (value.isPlaying) {
      unawaited(controller.pause());
    } else {
      unawaited(controller.play());
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: controller,
      builder: (context, value, _) {
        final icon = value.hasEnded
            ? Icons.replay_rounded
            : (value.isPlaying
                  ? Icons.pause_rounded
                  : Icons.play_arrow_rounded);
        return IconButton(
          onPressed: onPressed ?? _defaultAction,
          iconSize: iconSize,
          color: color,
          icon: Icon(icon),
          tooltip: value.isPlaying ? 'Pause' : 'Play',
        );
      },
    );
  }
}
