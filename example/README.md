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

The platform folders aren't checked in. Generate them first:

```bash
flutter create --platforms=android,ios,macos,web .
```

Then run:

```bash
flutter run -d chrome   # web
flutter run             # connected Android/iOS device
```

For an Android release build, add the `INTERNET` permission to
`android/app/src/main/AndroidManifest.xml`; for macOS, add the
`com.apple.security.network.client` entitlement (see the package README).
