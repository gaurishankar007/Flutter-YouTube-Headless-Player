import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:youtube_headless_player/src/core/constants/youtube_playback_rate.dart';
import 'package:youtube_headless_player/src/ui/controllers/youtube_player_controller.dart';

/// Playback speed selector.
class const YoutubeSpeedMenu({
  /// The controller to observe and act on.
  required final YoutubePlayerController controller,

  /// Icon color.
  final Color color = Colors.white,
  super.key,
}) extends StatelessWidget {
  /// Creates a speed menu bound to [controller].
  this;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: controller,
      builder: (context, value, _) {
        final rates = value.availablePlaybackRates.isNotEmpty
            ? value.availablePlaybackRates
            : YoutubePlaybackRate.all;
        return PopupMenuButton<double>(
          tooltip: 'Playback speed',
          icon: Icon(Icons.speed_rounded, color: color),
          initialValue: value.playbackRate,
          onSelected: (rate) => unawaited(controller.setPlaybackRate(rate)),
          itemBuilder: (context) {
            return [
              for (final rate in rates)
                PopupMenuItem<double>(
                  value: rate,
                  child: Text(
                    rate == value.playbackRate
                        ? '✓ ${YoutubePlaybackRate.label(rate)}'
                        : YoutubePlaybackRate.label(rate),
                  ),
                ),
            ];
          },
        );
      },
    );
  }
}
