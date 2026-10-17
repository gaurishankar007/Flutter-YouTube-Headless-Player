# YouTube Headless Player

<div>
  <a href="https://pub.dev/packages/youtube_headless_player"><img src="https://img.shields.io/pub/v/youtube_headless_player.svg" alt="pub"></a>
  <a href="https://opensource.org/licenses/MIT"><img src="https://img.shields.io/badge/license-MIT-blue.svg" alt="license: MIT"></a>
</div>

---

A YouTube player for Flutter whose interface is built entirely in Flutter. Use the ready-made YouTube-style controls, or build your own from scratch. Works the same way on Android, iOS and Web.

Video playback runs in a hidden WebView through the official [YouTube IFrame Player API](https://developers.google.com/youtube/iframe_api_reference), but viewers never touch it: every button, slider, gesture and menu is a Flutter widget you can style, rearrange or replace.

**Use it when you want to:**

- Match the player to your app's design instead of YouTube's embed UI
- Keep viewers inside your app — nothing in the player can open YouTube pages, popups or ads pages
- Switch between videos (e.g. camera angles of the same performance) without losing the playback position
- React to playback in your own code through typed state and events

## 🎯 Features

- Play, pause, stop, replay, loop and seek — the seek bar never jumps back while the video loads
- Load videos from any YouTube link (`watch`, `youtu.be`, `embed`, `shorts`, `live`) or a plain video id
- Switch to another video while keeping the current position and play/pause state
- Change playback speed (0.25×–2×), volume and mute
- Turn closed captions on or off for videos that have them
- Get thumbnail URLs in five resolutions, WebP or JPEG, for previews and placeholders
- YouTube-style controls out of the box: seek bar with buffering progress, play/pause, time label, speed menu, captions, volume and fullscreen buttons
- Controls auto-hide while watching and stay visible while they are being used
- Double-tap left/right to skip 10 seconds, double-tap center to play/pause
- Keyboard shortcuts on web: <kbd>space</kbd>/<kbd>k</kbd> play-pause, arrow keys to seek and change volume, <kbd>m</kbd> mute, <kbd>f</kbd> fullscreen, <kbd>0</kbd>–<kbd>9</kbd> to jump through the video
- Fullscreen with landscape rotation and hidden system bars; the video keeps playing without restarting and the back gesture exits fullscreen
- Every control is a standalone widget, so you can compose any subset into your own overlay
- Reactive `ValueNotifier` state and a typed, exhaustively switchable event stream

## ⚙️ Getting Started

Requires Flutter 3.47.0 or newer.

Add the following line to `pubspec.yaml`:

```yaml
dependencies:
  youtube_headless_player: ^0.1.0
```

### Web

Add the `flutter_inappwebview` web support script to your app's `web/index.html`. Without it, the player stays in the loading state:

```html
<head>
  ...
  <script type="application/javascript"
          src="/assets/packages/flutter_inappwebview_web/assets/web/web_support.js"
          defer></script>
</head>
```

### Android / iOS

No extra setup. Note that `flutter_inappwebview_android` 1.1.x requires AGP 8.x or older.

## 🚀 Usage

One widget is all you need. The controls and fullscreen handling (including the back gesture) are built in:

```dart
import 'package:youtube_headless_player/youtube_headless_player.dart';

class VideoPage extends StatefulWidget {
  const VideoPage({super.key});

  @override
  State<VideoPage> createState() => _VideoPageState();
}

class _VideoPageState extends State<VideoPage> {
  final controller = YoutubePlayerController.fromUrl(
    'https://youtu.be/dQw4w9WgXcQ', // any YouTube URL form, or a bare id
    autoPlay: true,
    startMuted: true, // needed for reliable autoplay under browser policies
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(child: YoutubePlayer(controller: controller)),
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}
```

A bare id works with the default constructor too: `YoutubePlayerController(initialVideoId: 'dQw4w9WgXcQ')`.

`YoutubePlayer` can be customized with `showControls: false` for a bare video surface, `controls:` for your own overlay, `handleFullscreen: false` to own the fullscreen layout, plus `fit`, `aspectRatio`, `placeholder`, `loadingWidget`, `backgroundColor` and `onReady`.

### Listening to state and events

```dart
// Reactive snapshot — rebuild UI with ValueListenableBuilder.
controller.value.isPlaying;
controller.value.position;
controller.value.bufferedFraction;

// Typed event stream — sealed classes, exhaustively switchable.
controller.events.listen((event) {
  switch (event) {
    case EndedEvent():
      // ...
    case ErrorEvent(:final message):
      // ...
    default:
      break;
  }
});
```

### Switching videos while keeping the position

The new video resumes from the current position, and a paused player stays paused:

```dart
await controller.loadNewVideo('https://youtu.be/dQw4w9WgXcQ');

// Plain id extraction is also available:
final id = YoutubePlayerController.convertUrlToId(url);
```

### Thumbnails

```dart
// From a URL (any form) or a bare id:
final preview = YoutubePlayerController.getThumbnailUrl(
  'https://youtu.be/dQw4w9WgXcQ',
  quality: YoutubeThumbnailQuality.medium,
);

// For the current video, e.g. as the player placeholder:
YoutubePlayer(
  controller: controller,
  placeholder: Image.network(controller.thumbnailUrl()!, fit: BoxFit.cover),
);
```

On Flutter Web, pass `webHtmlElementStrategy: WebHtmlElementStrategy.fallback` to `Image.network`, since `ytimg.com` serves no CORS headers.

### Fullscreen

Call `controller.toggleFullscreen()` (or tap the controls' fullscreen button). `YoutubePlayer` moves the video into a fullscreen page without restarting it, and the system back gesture exits fullscreen.

To build your own fullscreen layout, set `handleFullscreen: false` and react to `value.isFullscreen`. Keep the player inside a `GlobalKey`ed subtree that appears in exactly one place per frame, otherwise the video restarts.

Apps that lock orientations globally should set `YoutubeFullscreenManager.restoreOrientations` once at startup, so their lock is re-applied after leaving fullscreen.

### Good to know

- **Quality selection** isn't supported by YouTube embeds anymore; quality is chosen adaptively, so the controls hide the quality menu by default.
- **Autoplay** is subject to platform policies — combine `autoPlay: true` with `startMuted: true`.
- Videos whose owners disable embedding fail with error 101/150. That's a per-video restriction, not a player issue.

A complete demo app (minimal setup, built-in controls with video switching and a live event log, and a fully custom UI built from the standalone widgets) lives in [`example/`](https://github.com/gaurishankar007/Flutter-YouTube-Headless-Player/tree/main/example).

Curious how it works under the hood? See the [architecture doc](https://github.com/gaurishankar007/Flutter-YouTube-Headless-Player/blob/main/docs/architecture.md).

## ❤️ Additional information

Pull requests are welcomed!

If you encounter any problems or you have any ideas, feel free to [open an issue](https://github.com/gaurishankar007/Flutter-YouTube-Headless-Player/issues).
