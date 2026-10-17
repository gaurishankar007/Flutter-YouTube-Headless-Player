# Architecture

How `youtube_headless_player` is built: the layers, how Flutter and the
WebView talk to each other, and what differs between platforms. You don't
need any of this to use the package — it is for contributors and anyone
curious about the internals.

The core idea: the WebView is a **headless playback engine**. It renders no
controls, no buttons, no progress bar, and never receives a single pointer
event. **Flutter owns 100% of the user interface.**

---

## Overview

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
player.js (window.youtubeHeadlessPlayer)    assets/youtube/player.js
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
- Commands issued before the player is ready are queued and flushed on
  `ready`.

---

## Folder structure

The package follows a layered structure (`core` / `domain` / `data` /
`ui`), one declaration per file:

```
lib/
├── youtube_headless_player.dart            # public barrel — the only import you need
└── src/
    ├── core/                              # dependency-free shared primitives
    │   ├── constants/
    │   │   ├── youtube_playback_rate.dart        # canonical playback rates + labels
    │   │   └── youtube_thumbnail_quality.dart    # thumbnail resolutions
    │   └── utils/
    │       ├── youtube_duration_formatter.dart   # m:ss / h:mm:ss formatting
    │       ├── youtube_fullscreen_manager.dart   # SystemChrome enter/exit
    │       ├── youtube_thumbnail_util.dart       # thumbnail URL builder
    │       └── youtube_url_parser.dart           # video id extraction from URLs
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
    │           ├── youtube_web_assets_stub.dart  # no-op on Android/iOS
    │           ├── youtube_web_assets_web.dart   # engine asset URL resolver (web)
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
                ├── youtube_captions_button.dart
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

Layering rules: `core` depends on nothing, `domain` only on `core`, `data`
on `domain`/`core`, and `ui` may use all of them. Only the barrel
(`youtube_headless_player.dart`) is public API; `youtube_bridge.dart`,
`youtube_controller_impl.dart`, `youtube_webview.dart` and the platform
files are internal and not exported.

---

## How each module works

### `assets/youtube/player.js` — the playback engine

An IIFE exposing one global, `window.youtubeHeadlessPlayer`. Internally it
is class-based:

- `EventChannel` — posts JSON events to Flutter.
- `ProgressReporter` — owns the 250 ms progress timer.
- `YoutubePlayerEngine` — wraps `YT.Player`, lazy-loads the IFrame API
  script and translates its callbacks into events.
- `YoutubeHeadlessPlayer` — the facade with the imperative API plus the
  `dispatch` command router.

Robustness details:

- `initialize` is idempotent.
- The engine announces `pageReady` every 300 ms until it receives
  `initialize`, closing the race where a command evaluated before the
  script loaded would be lost silently.
- Mute/volume commands announce their *intended* state (the IFrame proxy
  applies commands asynchronously, so read-backs lie for a few hundred ms)
  and a drift check on each progress tick reconciles with reality.

### `src/data/services/youtube_bridge.dart` — the transport

Serializes `YoutubeCommand` objects to JSON and evaluates a single
`dispatch(...)` call; decodes incoming JSON payloads into the typed
`YoutubePlayerEvent` hierarchy. Also owns the per-instance `playerId` used
to route events when multiple players exist on one page.

### `src/ui/controllers/` — state management

`YoutubePlayerController extends ValueNotifier<YoutubePlayerValue>`,
mirroring Flutter's `VideoPlayerController` idiom: the controller notifies,
the value stays immutable.

The internal `YoutubeControllerImpl` (reached through a package-private
registry, never exported) owns the bridge, the broadcast event stream, the
pre-ready command queue, the event → value reducer, and the *seek latch*:
while a seek is in flight, stale progress reports cannot move the position
until the engine lands within 2 s of the target (5 s timeout). That is why
the scrubber never snaps back, just like real YouTube.

### `src/ui/views/youtube_webview.dart` — the WebView host

Configures `InAppWebView` (inline playback, no user-gesture requirement, no
zoom/scroll, context menu disabled), loads the engine document per
platform (see [Platform differences](#platform-differences)), enforces the
navigation allowlist and blocks popups.

### `src/ui/views/youtube_player.dart` — the all-in-one widget

Wraps the WebView in `IgnorePointer` inside an `AspectRatio` (default
16:9), applies `BoxFit` via `applyBoxFit`, shows a placeholder/loading
widget until the `ready` event arrives, and layers the `YoutubeControls`
overlay on top.

It also owns fullscreen (`handleFullscreen`): when `value.isFullscreen`
flips, it pushes/pops a black fullscreen page on the root navigator and
moves its `GlobalKey`ed content into it, so the WebView is **reparented —
never recreated** — and the back gesture naturally exits fullscreen.

### `src/ui/views/widgets/` — the controls

Every control is an independent widget bound to the controller via
`ValueListenableBuilder`, so any subset can be composed into a custom UI.
`YoutubeControls` assembles them into the full overlay and owns
visibility: chrome auto-hides 3 s after the player becomes ready and again
3 s after any interaction stops (regardless of play/pause state); any
pointer activity (scrubbing, slider drags, hovering) restarts the
countdown.

---

## Security

- The WebView sits behind `IgnorePointer` and (on web) disables pointer
  events on its own iframe — it can never be interacted with directly.
- Context menu, text selection, long press and drag are disabled in the
  page.
- Navigation interception: every main-frame navigation is cancelled and
  sub-frame requests are allowlisted to YouTube/Google hosts, so YouTube
  pages can never open from inside the WebView; popups are blocked.

---

## Platform differences

| Concern | Android / iOS | Web |
|---|---|---|
| Engine document loading | `index.html` + `player.js` are read from assets, the script tag is inlined, and the document is loaded via `loadData` with base URL `https://youtube-nocookie.com`, giving the engine a YouTube origin (required for embed-restricted videos) | The asset is loaded **by URL** from the app's own origin (resolved against the document's `<base href>`, not the current route), so the relative `player.js` reference and same-origin iframe access both work |
| `origin` player var | **Omitted** — echoing the spoofed base URL back to the API triggers "Video unavailable" embed errors (150/152/153) | Set to the real app origin |
| JS → Flutter events | `window.flutter_inappwebview.callHandler(...)` (native JS handler) | The web platform does not implement JS handlers, so the engine posts JSON strings to the parent window via `postMessage`, tagged with a `playerId` query parameter; a `dart:js_interop` listener (conditional import) decodes them |
| Flutter → JS commands | `evaluateJavascript` (native) | `evaluateJavascript` via the plugin's `web_support.js` — **must be included in the app's `web/index.html`** |
| Pointer isolation | The WebView is wrapped in `IgnorePointer` | Additionally, the engine page sets `pointer-events: none` on its own hosting iframe — otherwise the DOM iframe would swallow clicks before Flutter ever saw them |
| Navigation interception | `shouldOverrideUrlLoading` allowlist + popup blocking | Not supported by the platform; the iframe `allow` list is restricted instead |
| Fullscreen side effects | `SystemChrome`: immersive-sticky UI + forced landscape, restored on exit | No system chrome — the app just reacts to `value.isFullscreen` by expanding the layout; the browser fullscreen API is never used |
| Default controls layout | No volume control (hardware buttons), no bottom play/pause (center button only) — like the YouTube mobile app | Volume with hover-reveal slider + bottom play/pause — like the YouTube web player |
| Keyboard shortcuts | Inert | Active |

---

## Why quality selection is hidden

YouTube removed programmatic quality control from the IFrame API — both
`setPlaybackQuality` and the legacy `setPlaybackQualityRange` are no-ops
server-side. Quality is chosen adaptively; the level actually in use is
reported through `QualityChangedEvent` / `value.quality`. `YoutubeQualityMenu`
still exists, but `YoutubeControls` hides it by default for this reason.

---

## Language level

The package targets Dart 3.13 / Flutter 3.47 and uses the idioms they allow:
primary constructors (`class const Foo({required final int a}) extends Bar`),
dot shorthands (`.zero`, `const .all(12)`, `case .space || .keyK:`) and
patterns (switch expressions, map patterns). Public constructors keep their
doc comment on a `this;` body, which `public_member_api_docs` requires.
