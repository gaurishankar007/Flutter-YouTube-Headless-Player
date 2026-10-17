import 'package:meta/meta.dart';

/// Delivers JSON commands to the JavaScript playback engine.
///
/// Implemented by each platform's engine view: the native one evaluates a
/// `dispatch(...)` call inside `webview_flutter`, the web one calls the
/// engine directly inside its same-origin iframe. Events travel the other
/// way through `YoutubeBridge.receive`.
@internal
abstract interface class YoutubeEngineTransport {
  /// Hands [command] to `window.youtubeHeadlessPlayer.dispatch`.
  Future<void> dispatch(Map<String, Object?> command);
}
