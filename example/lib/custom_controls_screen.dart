import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:youtube_headless_player/youtube_headless_player.dart';

import 'demo_videos.dart';

/// Brand colors for the custom seek bar, replacing YouTube red.
const YoutubeProgressBarColors _progressBarColors = YoutubeProgressBarColors(
  played: Colors.tealAccent,
  thumb: Colors.tealAccent,
);

/// Seek amount for double taps and the ±10 s buttons.
const Duration _seekStep = Duration(seconds: 10);

/// A custom UI: the default overlay is replaced with one composed from the
/// package's standalone control widgets, and the player is also driven by
/// plain buttons through the controller.
class const CustomControlsScreen({super.key}) extends StatefulWidget {
  @override
  State<CustomControlsScreen> createState() => _CustomControlsScreenState();
}

class _CustomControlsScreenState extends State<CustomControlsScreen> {
  // A bare id works with the default constructor; options such as a start
  // position and looping are set up front.
  final _controller = YoutubePlayerController(
    initialVideoId: YoutubePlayerController.convertUrlToId(demoVideos[1].url),
    startAt: const Duration(seconds: 30),
    loop: true,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Custom controls')),
      body: Column(
        children: [
          // `controls` replaces the default overlay and follows the player
          // into fullscreen.
          YoutubePlayer(
            controller: _controller,
            controls: _CustomOverlay(controller: _controller),
          ),
          Expanded(
            child: ListView(
              padding: const .all(12),
              children: [
                _CommandPanel(controller: _controller),
                const Divider(height: 32),
                _StatePanel(controller: _controller),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// An overlay assembled from standalone widgets: gestures, seek bar,
/// play/pause, time, captions, speed, volume and fullscreen.
class const _CustomOverlay({required final YoutubePlayerController controller})
    extends StatelessWidget {
  void _togglePlayPause() {
    unawaited(
      controller.value.isPlaying ? controller.pause() : controller.play(),
    );
  }

  void _seekBy(Duration offset) {
    unawaited(controller.seekTo(controller.value.position + offset));
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: .expand,
      children: [
        YoutubeGestureDetector(
          seekStep: _seekStep,
          onTap: _togglePlayPause,
          onDoubleTapCenter: _togglePlayPause,
          onDoubleTapBackward: () => _seekBy(-_seekStep),
          onDoubleTapForward: () => _seekBy(_seekStep),
        ),
        ValueListenableBuilder(
          valueListenable: controller,
          builder: (context, value, _) {
            if (value.hasError) {
              return Center(
                child: YoutubeErrorBanner(message: value.errorMessage),
              );
            }
            if (value.isBuffering || value.isPendingAutoplay) {
              return const Center(
                child: CircularProgressIndicator(color: Colors.tealAccent),
              );
            }
            return const SizedBox.shrink();
          },
        ),
        Align(
          alignment: .bottomCenter,
          child: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: .topCenter,
                end: .bottomCenter,
                colors: [Colors.transparent, Colors.black87],
              ),
            ),
            child: Padding(
              padding: const .symmetric(horizontal: 8),
              child: Column(
                mainAxisSize: .min,
                children: [
                  YoutubeProgressBar(
                    controller: controller,
                    colors: _progressBarColors,
                  ),
                  Row(
                    children: [
                      YoutubePlayPauseButton(controller: controller),
                      const SizedBox(width: 4),
                      YoutubeTimeLabel(controller: controller),
                      const Spacer(),
                      if (kIsWeb) YoutubeVolumeSlider(controller: controller),
                      YoutubeCaptionsButton(controller: controller),
                      YoutubeSpeedMenu(controller: controller),
                      YoutubeFullscreenButton(controller: controller),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Plain buttons calling the controller directly.
class const _CommandPanel({required final YoutubePlayerController controller})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: controller,
      builder: (context, value, _) {
        final commands = <(IconData, String, Future<void> Function())>[
          (Icons.replay, 'Replay', controller.replay),
          (Icons.stop, 'Stop', controller.stop),
          (
            Icons.replay_10,
            '-10 s',
            () => controller.seekTo(value.position - _seekStep),
          ),
          (
            Icons.forward_10,
            '+10 s',
            () => controller.seekTo(value.position + _seekStep),
          ),
          (
            Icons.skip_next,
            'Jump to 1:00',
            () => controller.seekTo(const Duration(minutes: 1)),
          ),
          if (value.isMuted)
            (Icons.volume_up, 'Unmute', controller.unMute)
          else
            (Icons.volume_off, 'Mute', controller.mute),
          (Icons.volume_down, 'Volume 30', () => controller.setVolume(30)),
          (
            Icons.speed,
            value.playbackRate == YoutubePlaybackRate.normal ? '2×' : '1×',
            () => controller.setPlaybackRate(
              value.playbackRate == YoutubePlaybackRate.normal
                  ? YoutubePlaybackRate.double_
                  : YoutubePlaybackRate.normal,
            ),
          ),
          (
            value.captionsEnabled
                ? Icons.closed_caption
                : Icons.closed_caption_off,
            value.captionsEnabled ? 'Captions off' : 'Captions on',
            controller.toggleCaptions,
          ),
          (Icons.fullscreen, 'Fullscreen', controller.enterFullscreen),
        ];

        return Column(
          crossAxisAlignment: .start,
          children: [
            Text('Commands', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (icon, label, command) in commands)
                  ActionChip(
                    avatar: Icon(icon, size: 18),
                    label: Text(label),
                    onPressed: () => unawaited(command()),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}

/// A live readout of [YoutubePlayerValue].
class const _StatePanel({required final YoutubePlayerController controller})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return ValueListenableBuilder(
      valueListenable: controller,
      builder: (context, value, _) {
        final rows = <(String, String)>[
          ('State', value.playerState.name),
          ('Video id', value.videoId ?? '-'),
          (
            'Position',
            '${formatYoutubeDuration(value.position)} / '
                '${formatYoutubeDuration(value.duration)}',
          ),
          ('Buffered', '${(value.bufferedFraction * 100).round()} %'),
          ('Volume', value.isMuted ? 'muted' : '${value.volume}'),
          ('Speed', '${value.playbackRate}×'),
          ('Quality', value.quality.label),
          ('Captions', value.captionsEnabled ? 'on' : 'off'),
        ];

        return Column(
          crossAxisAlignment: .start,
          children: [
            Text('Live state', style: textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final (label, text) in rows)
              Padding(
                padding: const .symmetric(vertical: 2),
                child: Row(
                  children: [
                    SizedBox(
                      width: 96,
                      child: Text(label, style: textTheme.bodySmall),
                    ),
                    Text(text, style: textTheme.bodyMedium),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}
