import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:youtube_headless_player/src/domain/models/youtube_quality.dart';
import 'package:youtube_headless_player/src/ui/controllers/youtube_player_controller.dart';

/// Playback quality selector.
///
/// **Best-effort hint only**: the modern YouTube IFrame embed ignores
/// programmatic quality selection, so this menu cannot force a stream
/// switch — YouTube keeps choosing the quality adaptively. The menu is
/// hidden by default in `YoutubeControls` for this reason.
class const YoutubeQualityMenu({
  /// The controller to observe and act on.
  required final YoutubePlayerController controller,

  /// Icon color.
  final Color color = Colors.white,
  super.key,
}) extends StatelessWidget {
  /// Creates a quality menu bound to [controller].
  this;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: controller,
      builder: (context, value, _) {
        // Offer only what the video actually provides (plus Auto); fall
        // back to the full list until the player reports availability.
        final qualities = value.availableQualities.isNotEmpty
            ? [
                YoutubeQuality.auto,
                ...value.availableQualities.where(
                  (quality) => quality != YoutubeQuality.auto,
                ),
              ]
            : YoutubeQuality.values;
        return PopupMenuButton<YoutubeQuality>(
          tooltip: 'Quality',
          icon: Icon(Icons.high_quality_outlined, color: color),
          initialValue: value.quality,
          onSelected: (quality) =>
              unawaited(controller.setPlaybackQuality(quality)),
          itemBuilder: (context) {
            return [
              for (final quality in qualities)
                PopupMenuItem<YoutubeQuality>(
                  value: quality,
                  child: Text(
                    quality == value.quality
                        ? '✓ ${quality.label}'
                        : quality.label,
                  ),
                ),
            ];
          },
        );
      },
    );
  }
}
