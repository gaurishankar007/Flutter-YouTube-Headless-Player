import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:youtube_headless_player/src/ui/controllers/youtube_player_controller.dart';

/// Fullscreen enter/exit toggle.
class const YoutubeFullscreenButton({
  /// The controller to observe and act on.
  required final YoutubePlayerController controller,

  /// Icon color.
  final Color color = Colors.white,
  super.key,
}) extends StatelessWidget {
  /// Creates a fullscreen button bound to [controller].
  this;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: controller,
      builder: (context, value, _) {
        return IconButton(
          onPressed: () => unawaited(controller.toggleFullscreen()),
          color: color,
          icon: Icon(
            value.isFullscreen
                ? Icons.fullscreen_exit_rounded
                : Icons.fullscreen_rounded,
          ),
          tooltip: value.isFullscreen ? 'Exit fullscreen' : 'Fullscreen',
        );
      },
    );
  }
}
