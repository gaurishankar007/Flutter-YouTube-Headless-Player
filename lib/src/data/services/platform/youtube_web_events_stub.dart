import 'package:flutter/foundation.dart';

/// Non-web stub of the browser `message` event listener.
///
/// On Android/iOS engine events arrive through the inappwebview JavaScript
/// handler instead, so these functions are never called. The web variant
/// lives in `youtube_web_events_web.dart` and is selected via a conditional
/// import in `youtube_bridge.dart`.
void registerYoutubeWebEventListener(
  String playerId,
  ValueChanged<Map<String, Object?>> onEvent,
) {}

/// Non-web stub; see [registerYoutubeWebEventListener].
void unregisterYoutubeWebEventListener(String playerId) {}
