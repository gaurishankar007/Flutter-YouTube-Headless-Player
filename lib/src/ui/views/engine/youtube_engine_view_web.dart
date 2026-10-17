import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:web/web.dart' as web;
import 'package:youtube_headless_player/src/core/constants/youtube_engine_assets.dart';
import 'package:youtube_headless_player/src/data/services/youtube_engine_transport.dart';
import 'package:youtube_headless_player/src/ui/controllers/youtube_controller_impl.dart';
import 'package:youtube_headless_player/src/ui/controllers/youtube_player_controller.dart';

/// The headless `<iframe>` hosting the YouTube playback engine on web.
///
/// No WebView plugin is involved: the engine document is served from the
/// app's own origin, so the iframe is same-origin and commands call the
/// engine directly. Events come back as `postMessage` JSON tagged with the
/// bridge's `playerId`. The native counterpart lives in
/// `youtube_engine_view_native.dart` and is selected by a conditional
/// import.
@internal
class const YoutubeEngineView({
  /// The controller whose engine lives inside this iframe.
  required final YoutubePlayerController controller,
  super.key,
}) extends StatefulWidget {
  /// Creates the iframe host bound to [controller].
  this;

  @override
  State<YoutubeEngineView> createState() => _YoutubeEngineViewState();
}

class _YoutubeEngineViewState extends State<YoutubeEngineView>
    implements YoutubeEngineTransport {
  web.HTMLIFrameElement? _iframe;
  late final JSFunction _messageListener = _handleMessage.toJS;

  YoutubeControllerImpl get _impl => youtubeControllerImplOf(widget.controller);

  @override
  void initState() {
    super.initState();
    _impl.attachEngine(this);
    web.window.addEventListener('message', _messageListener);
  }

  @override
  void dispose() {
    web.window.removeEventListener('message', _messageListener);
    _impl.detachEngine();
    _iframe = null;
    super.dispose();
  }

  @override
  Future<void> dispatch(Map<String, Object?> command) async {
    final contentWindow = _iframe?.contentWindow;
    if (contentWindow == null) {
      return;
    }
    _EngineWindow(contentWindow).youtubeHeadlessPlayer
        ?.dispatch(jsonEncode(command).toJS);
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView.fromTagName(
      tagName: 'iframe',
      onElementCreated: _configureIframe,
    );
  }

  void _configureIframe(Object element) {
    final iframe = element as web.HTMLIFrameElement;
    _iframe = iframe;
    iframe
      ..src = _engineUrl()
      ..allow = 'autoplay; encrypted-media; picture-in-picture'
      ..onload = ((web.Event _) {
        unawaited(_impl.onPageLoaded());
      }).toJS;
    // The player must never be interacted with directly: Flutter owns the
    // whole UI, and an interactive iframe would swallow clicks before the
    // Flutter controls painted on top ever saw them.
    iframe.style
      ..width = '100%'
      ..height = '100%'
      ..border = 'none'
      ..pointerEvents = 'none';
  }

  /// Resolves the engine document on the app's own origin, tagged with the
  /// bridge's player id so its `postMessage` events can be told apart.
  ///
  /// Resolution goes through the engine's asset manager and the document's
  /// `<base href>` — never `Uri.base`, which under a path URL strategy is
  /// the current route and would point the iframe at a non-existent path
  /// (SPA hosting then serves the app's own `index.html` into the player).
  String _engineUrl() {
    final assetUrl = ui_web.assetManager.getAssetUrl(YoutubeEngineAssets.html);
    return Uri.parse(web.document.baseURI)
        .resolve(assetUrl)
        .replace(queryParameters: {'playerId': _impl.playerId})
        .toString();
  }

  void _handleMessage(web.Event event) {
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
    if (decoded
        case {
          'source': YoutubeEngineAssets.webMessageSource,
          'playerId': final Object? id,
          'payload': final Map<Object?, Object?> payload,
        }
        when id == _impl.playerId) {
      _impl.receiveEnginePayload(Map<String, Object?>.from(payload));
    }
  }
}

/// The engine iframe's `window`, exposing the engine global.
extension type _EngineWindow(JSObject _) implements JSObject {
  external _Engine? get youtubeHeadlessPlayer;
}

/// `window.youtubeHeadlessPlayer` inside the engine iframe.
extension type _Engine(JSObject _) implements JSObject {
  external JSAny? dispatch(JSString command);
}
