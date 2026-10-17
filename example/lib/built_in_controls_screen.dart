import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:youtube_headless_player/youtube_headless_player.dart';

import 'demo_videos.dart';

/// Maximum number of entries kept in the on-screen event log.
const int _maxLogEntries = 30;

/// The built-in experience: one [YoutubePlayer] with its default controls,
/// a video list that switches videos while keeping the position, and a
/// live event log.
class const BuiltInControlsScreen({super.key}) extends StatefulWidget {
  @override
  State<BuiltInControlsScreen> createState() => _BuiltInControlsScreenState();
}

class _BuiltInControlsScreenState extends State<BuiltInControlsScreen> {
  late final YoutubePlayerController _controller;
  StreamSubscription<YoutubePlayerEvent>? _eventSubscription;
  final List<String> _eventLog = [];

  @override
  void initState() {
    super.initState();
    _controller = YoutubePlayerController.fromUrl(
      demoVideos.first.url,
      autoPlay: true,
      startMuted: true,
    );
    _eventSubscription = _controller.events.listen(_logEvent);
  }

  @override
  void dispose() {
    unawaited(_eventSubscription?.cancel());
    _controller.dispose();
    super.dispose();
  }

  void _logEvent(YoutubePlayerEvent event) {
    // Progress events arrive every 250 ms; keep the log readable.
    if (event is ProgressEvent) {
      return;
    }
    final description = switch (event) {
      ReadyEvent(:final duration) => 'ready (duration: $duration)',
      PlayingEvent() => 'playing',
      PausedEvent() => 'paused',
      BufferingEvent() => 'buffering',
      EndedEvent() => 'ended',
      IdleEvent() => 'idle',
      ErrorEvent(:final code, :final message) => 'error $code: $message',
      DurationChangedEvent(:final duration) => 'duration changed: $duration',
      QualityChangedEvent(:final quality) => 'quality: ${quality.label}',
      PlaybackRateChangedEvent(:final playbackRate) => 'rate: ${playbackRate}x',
      VolumeChangedEvent(:final volume, :final isMuted) =>
        'volume: $volume (muted: $isMuted)',
      CaptionsChangedEvent(:final isEnabled) => 'captions: $isEnabled',
      FullscreenChangedEvent(:final isFullscreen) =>
        'fullscreen: $isFullscreen',
      VideoLoadedEvent(:final videoId) => 'video loaded: $videoId',
      VideoCuedEvent(:final videoId) => 'video cued: $videoId',
      ProgressEvent() => '',
    };
    setState(() {
      _eventLog.insert(0, description);
      if (_eventLog.length > _maxLogEntries) {
        _eventLog.removeLast();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Built-in controls')),
      body: Column(
        children: [
          // One widget: the controls overlay and fullscreen handling
          // (including the back gesture) are built in.
          YoutubePlayer(
            controller: _controller,
            placeholder: Image.network(
              _controller.thumbnailUrl()!,
              fit: BoxFit.cover,
              webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                Text('Videos', style: textTheme.titleMedium),
                const SizedBox(height: 4),
                ValueListenableBuilder(
                  valueListenable: _controller,
                  builder: (context, value, _) => Column(
                    children: [
                      for (final video in demoVideos)
                        _VideoTile(
                          video: video,
                          isCurrent:
                              value.videoId ==
                              YoutubePlayerController.convertUrlToId(video.url),
                          // Switches videos while keeping the current
                          // playback position (like changing camera angles).
                          onTap: () =>
                              unawaited(_controller.loadNewVideo(video.url)),
                        ),
                    ],
                  ),
                ),
                const Divider(),
                Text('Events', style: textTheme.titleMedium),
                const SizedBox(height: 4),
                for (final entry in _eventLog)
                  Text(entry, style: textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class const _VideoTile({
  required final DemoVideo video,
  required final bool isCurrent,
  required final VoidCallback onTap,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      selected: isCurrent,
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Image.network(
          YoutubePlayerController.getThumbnailUrl(
            video.url,
            quality: YoutubeThumbnailQuality.medium,
          )!,
          width: 64,
          height: 36,
          fit: BoxFit.cover,
          webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
        ),
      ),
      title: Text(video.title),
      subtitle: Text(video.url),
      trailing: isCurrent ? const Icon(Icons.equalizer) : null,
      onTap: isCurrent ? null : onTap,
    );
  }
}
