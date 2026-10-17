import 'dart:convert';
import 'dart:js_interop';

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

/// Marker identifying engine messages among all `postMessage` traffic.
const String _messageSource = 'youtubeHeadlessPlayer';

final Map<String, JSFunction> _listeners = {};

/// Web implementation of the engine event listener.
///
/// The inappwebview web platform does not support JavaScript handlers, so
/// `player.js` posts every event to the parent window as a JSON string:
/// `{"source": "youtubeHeadlessPlayer", "playerId": ..., "payload": {...}}`.
/// This listens for those messages, filters them by [playerId] and forwards
/// the decoded payload to [onEvent].
void registerYoutubeWebEventListener(
  String playerId,
  ValueChanged<Map<String, Object?>> onEvent,
) {
  unregisterYoutubeWebEventListener(playerId);
  void handleMessage(web.Event event) {
    final data = (event as web.MessageEvent).data;
    if (data == null || !data.isA<JSString>()) {
      return;
    }
    final Object? decoded;
    try {
      decoded = jsonDecode((data as JSString).toDart);
    } on FormatException {
      return;
    }
    if (decoded is! Map ||
        decoded['source'] != _messageSource ||
        decoded['playerId'] != playerId) {
      return;
    }
    final payload = decoded['payload'];
    if (payload is Map) {
      onEvent(Map<String, Object?>.from(payload));
    }
  }

  final jsListener = handleMessage.toJS;
  _listeners[playerId] = jsListener;
  web.window.addEventListener('message', jsListener);
}

/// Removes the listener registered for [playerId], if any.
void unregisterYoutubeWebEventListener(String playerId) {
  final listener = _listeners.remove(playerId);
  if (listener != null) {
    web.window.removeEventListener('message', listener);
  }
}
