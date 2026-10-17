import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:youtube_headless_player/src/ui/controllers/youtube_player_controller.dart';

/// Closed-captions on/off toggle.
///
/// Captions only render for videos that provide (or auto-generate) a
/// caption track.
class YoutubeCaptionsButton extends StatelessWidget {
  /// Creates a captions toggle bound to [controller].
  const YoutubeCaptionsButton({
    required this.controller,
    this.color = Colors.white,
    super.key,
  });

  /// The controller to observe and act on.
  final YoutubePlayerController controller;

  /// Icon color.
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: controller,
      builder: (context, value, _) {
        return IconButton(
          onPressed: () => unawaited(controller.toggleCaptions()),
          color: color,
          icon: Icon(
            value.captionsEnabled
                ? Icons.closed_caption_rounded
                : Icons.closed_caption_off_outlined,
          ),
          tooltip: value.captionsEnabled
              ? 'Turn off captions'
              : 'Turn on captions',
        );
      },
    );
  }
}
