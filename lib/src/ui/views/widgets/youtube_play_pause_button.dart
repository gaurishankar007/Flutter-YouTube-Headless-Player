import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:youtube_headless_player/src/ui/controllers/youtube_player_controller.dart';

/// Play / pause / replay button reflecting the controller state.
class const YoutubePlayPauseButton({
  /// The controller to observe and act on.
  required final YoutubePlayerController controller,

  /// Icon size in logical pixels.
  final double iconSize = 28,

  /// Icon color.
  final Color color = Colors.white,

  /// Overrides the default play/pause/replay behavior when provided.
  final VoidCallback? onPressed,
  super.key,
}) extends StatelessWidget {
  /// Creates a play/pause button bound to [controller].
  this;

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
