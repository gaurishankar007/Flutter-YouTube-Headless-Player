# youtube_headless_player_example

Demo application for the `youtube_headless_player` package.

Shows the single-widget integration: one `YoutubePlayer` with its built-in
controls overlay and fullscreen handling (back gesture included), plus a
video list that switches videos while keeping the playback position
(`loadNewVideo`), thumbnail previews (`getThumbnailUrl`), and a live event
log fed by `controller.events`.

## Run

```bash
flutter run -d chrome   # web
flutter run             # connected Android/iOS device
```

Note: `web/index.html` includes the required
`flutter_inappwebview_web` support script, and
`android/settings.gradle.kts` pins AGP 8.12.1 (AGP 9 is incompatible with
`flutter_inappwebview_android` 1.1.x).
