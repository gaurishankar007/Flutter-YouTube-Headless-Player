import 'package:material_ui/material_ui.dart';
import 'package:youtube_headless_player/src/core/utils/youtube_duration_formatter.dart';
import 'package:youtube_headless_player/src/ui/controllers/youtube_player_controller.dart';

/// Live `position / duration` label (e.g. `1:23 / 22:24`).
class YoutubeTimeLabel extends StatelessWidget {
  /// Creates a time label bound to [controller].
  const YoutubeTimeLabel({
    required this.controller,
    this.style = const TextStyle(color: Colors.white, fontSize: 15),
    super.key,
  });

  /// The controller to observe.
  final YoutubePlayerController controller;

  /// Text style of the label.
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: controller,
      builder: (context, value, _) {
        return Text(
          '${formatYoutubeDuration(value.position)} / '
          '${formatYoutubeDuration(value.duration)}',
          style: style,
        );
      },
    );
  }
}
