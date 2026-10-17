import 'package:material_ui/material_ui.dart';
import 'package:youtube_headless_player/youtube_headless_player.dart';

import 'built_in_controls_screen.dart';
import 'custom_controls_screen.dart';

void main() {
  runApp(const ExampleApp());
}

/// Demo application for the `youtube_headless_player` package.
class const ExampleApp({super.key}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'youtube_headless_player example',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.red,
        brightness: Brightness.dark,
      ),
      home: const HomeScreen(),
    );
  }
}

/// Lists the demos, each on its own page with its own controller.
class const HomeScreen({super.key}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('YouTube Headless Player')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _DemoTile(
            icon: Icons.play_circle,
            title: 'Minimal setup',
            subtitle: 'One controller and one widget — nothing else.',
            builder: (_) => Scaffold(
              appBar: AppBar(title: const Text('Minimal setup')),
              body: const MinimalPlayer(),
            ),
          ),
          _DemoTile(
            icon: Icons.smart_display,
            title: 'Built-in controls',
            subtitle:
                'One YoutubePlayer widget with the YouTube-style overlay, '
                'video switching that keeps the position, thumbnails and a '
                'live event log.',
            builder: (_) => const BuiltInControlsScreen(),
          ),
          _DemoTile(
            icon: Icons.tune,
            title: 'Custom controls',
            subtitle:
                'Your own overlay composed from the standalone control '
                'widgets, programmatic commands and the live player state.',
            builder: (_) => const CustomControlsScreen(),
          ),
        ],
      ),
    );
  }
}

class const _DemoTile({
  required final IconData icon,
  required final String title,
  required final String subtitle,
  required final WidgetBuilder builder,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon, size: 32),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: () =>
            Navigator.of(context)
                .push(MaterialPageRoute<void>(builder: builder)),
      ),
    );
  }
}

/// The smallest possible integration, for reference: one controller and
/// one widget. The controls overlay and fullscreen handling (including the
/// back gesture) are built into [YoutubePlayer].
class const MinimalPlayer({super.key}) extends StatefulWidget {
  @override
  State<MinimalPlayer> createState() => _MinimalPlayerState();
}

class _MinimalPlayerState extends State<MinimalPlayer> {
  final _controller = YoutubePlayerController.fromUrl(
    'https://youtu.be/kfhcWQpl9v4', // any YouTube URL form, or a bare id
    autoPlay: true,
    startMuted: true, // needed for reliable autoplay under browser policies
  );

  @override
  Widget build(BuildContext context) {
    return YoutubePlayer(controller: _controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
