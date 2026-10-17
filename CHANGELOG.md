# Changelog

## 0.1.1

- Now requires Dart 3.13 (already included with Flutter 3.47, the minimum
  Flutter version).
- pub.dev now lists the supported platforms: Android, iOS and Web, plus
  macOS and Windows, which the underlying WebView supports but which
  haven't been tested yet.
- Rewrote the README around what the package does and how to use it; the
  internals moved to `doc/architecture.md`.
- The example app now has three demos: a minimal setup, the built-in
  controls, and a custom UI built from the standalone control widgets.

## 0.1.0

First release of `youtube_headless_player` — a YouTube player
with a fully custom interface, working the same way on Android, iOS, and
Web.

### Watching videos

- Play, pause, replay, and jump to any point in the video by tapping or
  dragging the seek bar — the bar never jumps back while the video loads.
- Switch to another video (for example a different camera angle) and keep
  watching from the same position, without losing the play/pause state.
- Open videos from any kind of YouTube link (`watch`, `youtu.be`,
  `shorts`, `embed`, `live`) or a plain video id.
- Change the playback speed (0.25× – 2×).
- Adjust the volume or mute/unmute (on web; phones use their volume
  buttons, like the YouTube app).
- Turn subtitles/closed captions on or off from the controls (for videos
  that have them).
- Watch in fullscreen — the app rotates to landscape and hides the system
  bars, the video keeps playing without restarting, and the back gesture
  exits fullscreen.

### Player interface

- YouTube-style controls drawn by the app itself: seek bar with buffering
  progress, play/pause, elapsed/total time, speed menu, volume, and
  fullscreen button.
- Tap anywhere on the video to play or pause, just like the YouTube web
  player.
- Controls hide automatically while watching and stay visible while you
  are using them; on web they reappear as soon as you move the mouse over
  the video.
- Double-tap the left or right side of the video to skip 10 seconds
  backward or forward.
- Keyboard shortcuts on web: space/`k` play-pause, arrow keys to seek and
  change volume, `m` mute, `f` fullscreen, `0`–`9` to jump through the
  video.
- On web, the mouse cursor becomes a hand over every control, and the
  volume slider appears when you hover over the speaker icon.
- A loading spinner while the video buffers, a clear message if a video
  cannot be played, and video thumbnails available for previews and
  placeholders.

### Safety

- Viewers stay in the app: nothing inside the player can open YouTube,
  show ads pages, pop up windows, or react to long-presses and
  right-clicks.
