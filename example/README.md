# youtube_headless_player_example

Demo application for the `youtube_headless_player` package.

The home screen lists three demos, each with its own controller:

- **Minimal setup** (`lib/main.dart`) — one controller and one
  `YoutubePlayer`, with autoplay (muted).
- **Built-in controls** (`lib/built_in_controls_screen.dart`) — the
  default YouTube-style overlay and fullscreen handling (back gesture
  included), a thumbnail placeholder, a video list that switches videos
  while keeping the playback position (`loadNewVideo`, `getThumbnailUrl`),
  and a live event log fed by `controller.events`.
- **Custom controls** (`lib/custom_controls_screen.dart`) — the default
  overlay replaced with one composed from the standalone widgets
  (`YoutubeGestureDetector`, `YoutubeProgressBar` with brand colors,
  play/pause, time, captions, speed, volume, fullscreen, error banner),
  buttons calling the controller directly (seek, replay, stop, mute,
  volume, speed, captions, fullscreen), and a live readout of
  `controller.value`.

## Run

```bash
flutter run -d chrome   # web
flutter run             # connected Android/iOS device
```

Note: `web/index.html` includes the required
`flutter_inappwebview_web` support script, and
`android/settings.gradle.kts` pins AGP 8.12.1 (AGP 9 is incompatible with
`flutter_inappwebview_android` 1.1.x).
