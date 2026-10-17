# youtube_headless_player

A fully custom YouTube player for Flutter (Android, iOS, Web), built on
[`flutter_inappwebview`](https://pub.dev/packages/flutter_inappwebview) and the
official [YouTube IFrame Player API](https://developers.google.com/youtube/iframe_api_reference).

The WebView is a **headless playback engine**: it renders no controls, no
buttons, no progress bar, and never receives a single pointer event.
**Flutter owns 100% of the user interface.**

---

## Features

**Playback**

- Load / cue videos (with optional start/end positions), play, pause, stop, replay
- `loadNewVideo(url)` — replace the running video with another one **while
  keeping the current playback position and play/pause state** (e.g. for
  switching camera angles of the same performance); accepts any YouTube URL
  form or a bare id
- URL parsing built in: `YoutubePlayerController.convertUrlToId` /
  `youtubeVideoIdFromUrl` handle `watch?v=`, `youtu.be/`, `embed/`,
  `shorts/`, `live/` and `/v/` links
- Thumbnail URLs for any video or the current one —
  `YoutubePlayerController.getThumbnail` / `getThumbnailUrl` /
  `controller.thumbnailUrl()` with five resolutions
  (`YoutubeThumbnailQuality`) in WebP or JPEG, e.g. for list previews or
  the `YoutubePlayer` placeholder
- Seeking with *latched* scrub positions — the timeline never snaps back while
  the engine executes a seek, just like the real YouTube player
- Playback speed selection (0.25×–2×, or whatever the video reports)
- Volume (0–100), mute/unmute with optimistic, self-correcting state
- Closed captions on/off (`setCaptionsEnabled`/`toggleCaptions`, initial
  `captionsEnabled`/`captionsLanguage` on the controller) — rendered for
  videos that provide or auto-generate a caption track
- Looping a single video

**State & events**

- `ValueNotifier`-based reactive state (`YoutubePlayerValue`) — position,
  duration, buffered fraction, volume, mute, rate, quality, availability
  lists, fullscreen, errors
- A sealed, exhaustively-switchable event stream (`Stream<YoutubePlayerEvent>`):
  ready, playing, paused, buffering, ended, idle, cued, loaded, progress
  (every 250 ms *only while playing*), duration/quality/rate/volume changes,
  fullscreen changes, typed errors
- Commands issued before the player is ready are queued and flushed on ready

**Flutter-rendered controls** (all optional, all composable)

- `YoutubeControls` — complete YouTube-style overlay: auto-hiding chrome that
  stays put while you interact with it, gradient scrim, center play/replay
  button, buffering spinner (also shown whenever an autoplay is pending —
  the initial startup, or a `loadVideo`/`loadNewVideo` switch — instead of
  looking paused or blank), error banner
- `YoutubeProgressBar` — scrubbable timeline with played/buffered segments,
  drag preview, tap-to-seek
- `YoutubeVolumeSlider` — hover/tap-revealed slider (YouTube web behavior)
- `YoutubeSpeedMenu`, `YoutubeQualityMenu`, `YoutubeCaptionsButton`,
  `YoutubeFullscreenButton`, `YoutubePlayPauseButton`, `YoutubeTimeLabel`,
  `YoutubeErrorBanner`
- `YoutubeGestureDetector` — on web, a single tap on the video always
  toggles play/pause and reveals the controls; on mobile, a single tap
  only shows/hides the controls, play/pause is reserved for the dedicated
  button. Double-tapping the center zone toggles play/pause on every
  platform, and double-tapping left/right seeks ±10 s with animated
  feedback; the auto-hidden controls also reappear on mouse hover
  (web/desktop)
- Keyboard shortcuts (desktop/web): <kbd>space</kbd>/<kbd>k</kbd> play-pause,
  <kbd>←</kbd>/<kbd>j</kbd> & <kbd>→</kbd>/<kbd>l</kbd> seek,
  <kbd>↑</kbd>/<kbd>↓</kbd> volume, <kbd>m</kbd> mute, <kbd>f</kbd>
  fullscreen, <kbd>0</kbd>–<kbd>9</kbd> percentage jump
- Hand cursor over every control on web/desktop

**Fullscreen**

- Controlled entirely by Flutter (`enterFullscreen` / `exitFullscreen` /
  `toggleFullscreen`) — system UI hidden and orientation rotated via
  `SystemChrome`; the browser fullscreen API is never used
- On exit every orientation is re-enabled by default; apps that lock
  orientations globally set `YoutubeFullscreenManager.restoreOrientations`
  once at startup to re-apply their own lock instead

**Security**

- The WebView sits behind `IgnorePointer` and (on web) disables pointer
  events on its own iframe — it can never be interacted with directly
- Context menu, text selection, long press and drag are disabled in the page
- Navigation interception: every main-frame navigation is cancelled and
  sub-frame requests are allowlisted to YouTube/Google hosts, so YouTube
  pages can never open from inside the WebView; popups are blocked

---

## Architecture

```
Flutter UI
    ↓
YoutubePlayer (widget)                      src/ui/views/
    ↓
YoutubePlayerController                     src/ui/controllers/
    ↓  JSON commands            ↑ typed events
YoutubeBridge                               src/data/services/
    ↓
flutter_inappwebview
    ↓
Minimal HTML (<div id="player"> only)       assets/youtube/index.html
    ↓
player.js (window.youtubeHeadlessPlayer)     assets/youtube/player.js
    ↓
YouTube IFrame API
```

- **Flutter → JavaScript** — every command is a JSON object dispatched
  through one entry point:
  `window.youtubeHeadlessPlayer.dispatch({action: 'seekTo', seconds: 120})`.
  No raw JavaScript strings are scattered through the codebase.
- **JavaScript → Flutter** — structured JSON events only, never plain
  strings: `{event: 'progress', position: 12.3, duration: 100, buffered: 0.44}`.
- Progress events are emitted every 250 ms while playing and stop while
  paused/buffering/ended, keeping bridge traffic minimal.

### Folder structure

The package follows a layered, architecture-first structure
(`core` / `domain` / `data` / `ui`), one declaration per file:

```
lib/
├── youtube_headless_player.dart            # public barrel — the only import you need
└── src/
    ├── core/                              # dependency-free shared primitives
    │   ├── constants/
    │   │   └── youtube_playback_rate.dart # canonical playback rates + labels
    │   └── utils/
    │       ├── youtube_duration_formatter.dart   # m:ss / h:mm:ss formatting
    │       └── youtube_fullscreen_manager.dart   # SystemChrome enter/exit
    ├── domain/                            # pure model layer (no Flutter UI, no IO)
    │   └── models/
    │       ├── youtube_player_event.dart  # sealed event hierarchy
    │       ├── youtube_player_state.dart  # YT.PlayerState mapping
    │       ├── youtube_player_value.dart  # immutable state snapshot
    │       └── youtube_quality.dart       # quality levels + wire codes
    ├── data/                              # engine transport layer
    │   └── services/
    │       ├── youtube_bridge.dart        # JSON command dispatch + event decode
    │       └── platform/
    │           ├── youtube_web_events_stub.dart  # no-op on Android/iOS
    │           └── youtube_web_events_web.dart   # postMessage listener (web)
    └── ui/                                # everything visual & stateful
        ├── controllers/
        │   ├── youtube_player_controller.dart    # public ValueNotifier API
        │   └── youtube_controller_impl.dart      # engine-facing internals
        ├── models/
        │   └── youtube_progress_bar_colors.dart  # UI-only styling model
        └── views/
            ├── youtube_player.dart        # the video surface widget
            ├── youtube_webview.dart       # headless InAppWebView host
            └── widgets/                   # one control per file
                ├── youtube_controls.dart
                ├── youtube_error_banner.dart
                ├── youtube_fullscreen_button.dart
                ├── youtube_gesture_detector.dart
                ├── youtube_play_pause_button.dart
                ├── youtube_progress_bar.dart
                ├── youtube_quality_menu.dart
                ├── youtube_speed_menu.dart
                ├── youtube_time_label.dart
                └── youtube_volume_slider.dart

assets/youtube/
├── index.html                             # <div id="player"> + minimal CSS, nothing else
└── player.js                              # ES6 engine wrapper around the IFrame API
```

Layering rules: `core` depends on nothing, `domain` only on `core`,
`data` on `domain`/`core`, and `ui` may use all of them. Only the barrel
(`youtube_headless_player.dart`) is public API; `youtube_bridge.dart`,
`youtube_controller_impl.dart`, `youtube_webview.dart` and the platform
event listeners are internal and not exported.

### How each module works

**`assets/youtube/player.js` — the playback engine.** An IIFE exposing one
global, `window.youtubeHeadlessPlayer`. Internally it is class-based:
`EventChannel` (posts JSON events to Flutter), `ProgressReporter` (owns the
250 ms timer), `YoutubePlayerEngine` (wraps `YT.Player`, lazy-loads the
IFrame API script, translates its callbacks into events) and
`YoutubeHeadlessPlayer` (the facade with the imperative API plus the
`dispatch` command router). Robustness details: `initialize` is idempotent;
the engine announces `pageReady` every 300 ms until it receives
`initialize`, closing the race where a command evaluated before the script
loaded would be lost silently; mute/volume commands announce their
*intended* state (the IFrame proxy applies commands asynchronously, so
read-backs lie for a few hundred ms) and a drift check on each progress
tick reconciles with reality.

**`src/data/services/youtube_bridge.dart` — the transport.** Serializes
`YoutubeCommand` objects to JSON and evaluates a single
`dispatch(...)` call; decodes incoming JSON payloads into the typed
`YoutubePlayerEvent` hierarchy. Also owns the per-instance `playerId` used
to route events when multiple players exist on one page.

**`src/ui/controllers/` — state management.**
`YoutubePlayerController extends ValueNotifier<YoutubePlayerValue>`,
mirroring Flutter's `VideoPlayerController` idiom: the controller notifies,
the value stays immutable. The internal `YoutubeControllerImpl` (reached
through a package-private registry, never exported) owns the bridge, the
broadcast event stream, the pre-ready command queue, the event→value
reducer, and the *seek latch*: while a seek is in flight, stale progress
reports cannot move the position until the engine lands within 2 s of the
target (5 s timeout), which is why the scrubber behaves like real YouTube.

**`src/ui/views/youtube_webview.dart` — the WebView host.** Configures
`InAppWebView` (inline playback, no user-gesture requirement, no zoom/scroll,
context menu disabled), loads the engine document per platform (see below),
enforces the navigation allowlist and blocks popups.

**`src/ui/views/youtube_player.dart` — the all-in-one widget.** Wraps the
WebView in `IgnorePointer` inside an `AspectRatio` (default 16:9), applies
`BoxFit` via `applyBoxFit`, shows a placeholder/loading widget until the
`ready` event arrives, and layers the `YoutubeControls` overlay on top
(`showControls`/`controls` to customize). It also owns fullscreen
(`handleFullscreen`): when `value.isFullscreen` flips, it pushes/pops a
black fullscreen page on the root navigator and moves its `GlobalKey`ed
content into it, so the WebView is reparented — never recreated — and the
back gesture naturally exits fullscreen.

**`src/ui/views/widgets/` — the controls.** Every control is an independent
widget bound to the controller via `ValueListenableBuilder`, so any subset
can be composed into a custom UI. `YoutubeControls` assembles them into the
full overlay and owns visibility: chrome auto-hides 3 s after the player
becomes ready and again 3 s after any interaction stops (regardless of
play/pause state); any pointer activity (scrubbing, slider drags, hovering)
restarts the countdown.

---

## Platform differences

| Concern | Android / iOS | Web |
|---|---|---|
| Engine document loading | `index.html` + `player.js` are read from assets, the script tag is inlined, and the document is loaded via `loadData` with base URL `https://youtube-nocookie.com`, giving the engine a YouTube origin (required for embed-restricted videos) | The asset is loaded **by URL** from the app's own origin, so the relative `player.js` reference and same-origin iframe access both work |
| `origin` player var | **Omitted** — echoing the spoofed base URL back to the API triggers "Video unavailable" embed errors (150/152/153) | Set to the real app origin |
| JS → Flutter events | `window.flutter_inappwebview.callHandler(...)` (native JS handler) | The web platform does not implement JS handlers, so the engine posts JSON strings to the parent window via `postMessage`, tagged with a `playerId` query parameter; a `dart:js_interop` listener (conditional import) decodes them |
| Flutter → JS commands | `evaluateJavascript` (native) | `evaluateJavascript` via the plugin's `web_support.js` — **must be included in your `web/index.html`** (see Setup) |
| Pointer isolation | The WebView is wrapped in `IgnorePointer` | Additionally, the engine page sets `pointer-events: none` on its own hosting iframe — otherwise the DOM iframe would swallow clicks before Flutter ever saw them |
| Navigation interception | `shouldOverrideUrlLoading` allowlist + popup blocking | Not supported by the platform; the iframe `allow` list is restricted instead |
| Fullscreen side effects | `SystemChrome`: immersive-sticky UI + forced landscape, restored on exit | No system chrome — the app just reacts to `value.isFullscreen` by expanding the layout |
| Default controls layout | No volume control (hardware buttons), no bottom play/pause (center button only) — like the YouTube mobile app | Volume with hover-reveal slider + bottom play/pause — like the YouTube web player |
| Keyboard shortcuts | Inert | Active |

---

## Setup

### Web (required)

`flutter_inappwebview` needs its web support script in your app's
`web/index.html` — without it, commands never reach the player and the
player stays in the loading state:

```html
<head>
  ...
  <script type="application/javascript"
          src="/assets/packages/flutter_inappwebview_web/assets/web/web_support.js"
          defer></script>
</head>
```

### Android / iOS

No extra setup. Note that `flutter_inappwebview_android` 1.1.x requires
AGP ≤ 8.x (AGP 9 removes an API it still uses).

---

## Quick start

One widget is all you need — the controls overlay and fullscreen handling
(including the back gesture) are built in:

```dart
import 'package:youtube_headless_player/youtube_headless_player.dart';

final controller = YoutubePlayerController.fromUrl(
  'https://youtu.be/dQw4w9WgXcQ', // any YouTube URL form, or a bare id
  autoPlay: true,
  startMuted: true, // required for reliable autoplay under browser policies
);
// A bare id also works with the default constructor:
// YoutubePlayerController(initialVideoId: 'dQw4w9WgXcQ');

@override
Widget build(BuildContext context) {
  return YoutubePlayer(controller: controller);
}

@override
void dispose() {
  controller.dispose();
  super.dispose();
}
```

Customization points on the same widget: `showControls: false` for a bare
surface, `controls:` for your own overlay, `handleFullscreen: false` to
own the fullscreen layout, plus `fit`, `aspectRatio`, `placeholder`,
`loadingWidget`, `backgroundColor` and `onReady`.

### State & events

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

```dart
// Accepts full YouTube URLs (watch, youtu.be, embed, shorts, live) or ids.
// The new video resumes from the current position, and a paused player is
// re-paused once the new video is ready — ideal for camera-angle switching.
await controller.loadNewVideo('https://youtu.be/dQw4w9WgXcQ');

// Plain id extraction is also available:
final id = YoutubePlayerController.convertUrlToId(url);
```

### Thumbnails

```dart
// From a URL (any form) or a bare id:
final listPreview = YoutubePlayerController.getThumbnailUrl(
  'https://youtu.be/dQw4w9WgXcQ',
  quality: YoutubeThumbnailQuality.medium,
);

// For the currently loaded video — e.g. as the player placeholder:
YoutubePlayer(
  controller: controller,
  placeholder: Image.network(controller.thumbnailUrl()!, fit: BoxFit.cover),
);
```

> **Web note:** `ytimg.com` serves no CORS headers, so on Flutter Web pass
> `webHtmlElementStrategy: WebHtmlElementStrategy.fallback` to
> `Image.network` (the engine then falls back to an `<img>` element).

### Fullscreen

**Built in.** When the controller enters fullscreen (`toggleFullscreen()`
or the controls' button), `YoutubePlayer` pushes a black fullscreen page
on the root navigator and moves itself into it *without recreating the
WebView* (GlobalKey reparenting), so playback continues seamlessly. The
system back button/gesture pops that page and exits fullscreen — no
`PopScope` wiring needed. The controller also applies the platform side
effects: `SystemChrome` immersive UI + landscape rotation on Android/iOS;
nothing on web, where there is no system chrome and the browser
fullscreen API is deliberately unused.

Want to own the fullscreen layout instead? Set `handleFullscreen: false`
and rearrange your layout on `FullscreenChangedEvent` /
`value.isFullscreen`. Keep the player inside a `GlobalKey`ed subtree
(`KeyedSubtree`) that appears in exactly one place per frame, so Flutter
*reparents* it into the new layout instead of recreating it — otherwise
the WebView is torn down and the video restarts.

---

## Known platform limitations

- **Quality selection is not honored by modern YouTube embeds.** YouTube
  removed programmatic quality control from the IFrame API — both
  `setPlaybackQuality` and the legacy `setPlaybackQualityRange` are no-ops
  server-side (verified against the current player). Quality is chosen
  adaptively; the level actually in use is reported through
  `QualityChangedEvent` / `value.quality`. `YoutubeControls` hides its
  quality menu by default for this reason.
- **Autoplay** is subject to platform policies — combine `autoPlay: true`
  with `startMuted: true`.
- Videos whose owners disable embedding fail with error 101/150 — that is a
  per-video restriction, not a player issue.

---

## Example

A complete demo app (video switching, fullscreen with back-gesture
handling, live event log) lives in [`example/`](example/lib/main.dart).
