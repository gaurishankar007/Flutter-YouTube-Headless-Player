import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:youtube_headless_player/youtube_headless_player.dart';

void main() {
  runApp(const ExampleApp());
}

/// Demo application for the `youtube_headless_player` package.
class ExampleApp extends StatelessWidget {
  /// Creates the demo app.
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'youtube_headless_player example',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.red,
        brightness: Brightness.dark,
      ),
      home: const PlayerScreen(),
    );
  }
}

/// A sample video the demo can switch between.
///
/// Holds full YouTube URLs (in different forms on purpose) to exercise the
/// package's URL parsing and `loadNewVideo`.
class _DemoVideo {
  const _DemoVideo(this.url, this.title);

  final String url;
  final String title;
}

const List<_DemoVideo> _demoVideos = [
  _DemoVideo(
    'hdkuSz4MbDI',
    'Kirtans From The Sacred Forest { Kirtan 3 } Agnideva Dasa Prabhu',
  ),
  _DemoVideo(
    'https://youtu.be/kfhcWQpl9v4',
    'Jai Govinda Jai Gopala ~ Vaiyasaki Dasa',
  ),
  _DemoVideo(
    'https://www.youtube.com/embed/K6hfp4227bA',
    'Kirtans From The Sacred Forest { Kirtan 1 } Agnideva Dasa Prabhu',
  ),
];

/// Maximum number of entries kept in the on-screen event log.
const int _maxLogEntries = 30;

/// The main demo screen: player, controls, video list and event log.

/// The main demo screen: the player with its controls overlay.
class PlayerScreen extends StatefulWidget {
  /// Creates the demo screen.
  const PlayerScreen({super.key});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late final YoutubePlayerController _controller;
  StreamSubscription<YoutubePlayerEvent>? _eventSubscription;
  final List<String> _eventLog = [];

  @override
  void initState() {
    super.initState();
    _controller = YoutubePlayerController.fromUrl(_demoVideos.first.url);
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
    return Scaffold(
      backgroundColor: Colors.black,
      // One widget: the controls overlay and fullscreen handling
      // (including the back gesture) are built into YoutubePlayer.
      body: Column(
        spacing: 24,
        children: [
          YoutubePlayer(controller: _controller),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                Text('Videos', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                for (final video in _demoVideos)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
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
                    // Switches videos while keeping the current playback
                    // position (like changing camera angles).
                    onTap: () => unawaited(_controller.loadNewVideo(video.url)),
                  ),
                const Divider(),
                Text('Events', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                for (final entry in _eventLog)
                  Text(entry, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
