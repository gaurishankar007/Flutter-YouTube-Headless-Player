/// Locations of the bundled JavaScript playback engine.
abstract final class YoutubeEngineAssets {
  /// Root of the package's engine assets.
  static const String directory =
      'packages/youtube_headless_player/assets/youtube';

  /// The engine document: a bare `<div id="player">` plus minimal CSS.
  static const String html = '$directory/index.html';

  /// The engine script wrapping the YouTube IFrame Player API.
  static const String script = '$directory/player.js';

  /// Name of the channel the engine posts events to on native platforms.
  /// Must match `EVENT_CHANNEL` in `assets/youtube/player.js`.
  static const String eventChannel = 'YoutubePlayerEvents';

  /// Marker identifying engine messages among all `postMessage` traffic on
  /// web. Must match the `source` field posted by `assets/youtube/player.js`.
  static const String webMessageSource = 'youtubeHeadlessPlayer';
}
