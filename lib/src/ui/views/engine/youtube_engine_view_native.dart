import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';
import 'package:youtube_headless_player/src/core/constants/youtube_engine_assets.dart';
import 'package:youtube_headless_player/src/data/services/youtube_engine_transport.dart';
import 'package:youtube_headless_player/src/ui/controllers/youtube_controller_impl.dart';
import 'package:youtube_headless_player/src/ui/controllers/youtube_player_controller.dart';

/// The headless WebView hosting the YouTube playback engine on Android,
/// iOS and macOS.
///
/// Renders no chrome of its own and is expected to sit behind an
/// `IgnorePointer` — every user interaction is handled by Flutter widgets
/// layered on top.
///
/// `index.html` and `player.js` are read from the package assets, the
/// script tag is inlined, and the document is loaded with a YouTube base
/// URL so the IFrame API sees a proper origin (required for
/// embed-restricted videos). The web counterpart lives in
/// `youtube_engine_view_web.dart` and is selected by a conditional import.
@internal
class const YoutubeEngineView({
  /// The controller whose engine lives inside this WebView.
  required final YoutubePlayerController controller,
  super.key,
}) extends StatefulWidget {
  /// Creates the WebView host bound to [controller].
  this;

  @override
  State<YoutubeEngineView> createState() => _YoutubeEngineViewState();
}

class _YoutubeEngineViewState extends State<YoutubeEngineView>
    implements YoutubeEngineTransport {
  /// Base URL the engine document runs under.
  ///
  /// The privacy-enhanced host is what battle-tested players load under;
  /// combined with *not* echoing this origin into the player vars it avoids
  /// "Video unavailable" embed errors (150/152/153) that the regular host
  /// raises for spoofed origins.
  static const String _baseUrl = 'https://youtube-nocookie.com';

  /// Script tag in `index.html` replaced by the inlined engine.
  static const String _scriptTag = '<script src="player.js"></script>';

  /// Hosts that sub-frames may load from; everything else is cancelled.
  static const List<String> _allowedHosts = [
    'youtube.com',
    'youtube-nocookie.com',
    'ytimg.com',
    'googlevideo.com',
    'google.com',
    'gstatic.com',
    'googleapis.com',
  ];

  late final WebViewController _webViewController = _createWebViewController();

  YoutubeControllerImpl get _impl => youtubeControllerImplOf(widget.controller);

  @override
  void initState() {
    super.initState();
    _impl.attachEngine(this);
    unawaited(_loadEngine());
  }

  @override
  void dispose() {
    _impl.detachEngine();
    super.dispose();
  }

  @override
  Future<void> dispatch(Map<String, Object?> command) async {
    // `jsonEncode` output is a valid JavaScript object literal, so the
    // command travels as data — never as interpolated code fragments.
    // `void` discards the result, which WebKit can't always serialize.
    try {
      await _webViewController.runJavaScript(
        'void (window.youtubeHeadlessPlayer && '
        'window.youtubeHeadlessPlayer.dispatch(${jsonEncode(command)}))',
      );
    } on PlatformException {
      // The document isn't loaded yet; `initialize` is re-sent on every
      // `pageReady` announcement, and other commands wait for `ready`.
    }
  }

  @override
  Widget build(BuildContext context) {
    return WebViewWidget(controller: _webViewController);
  }

  WebViewController _createWebViewController() {
    final PlatformWebViewControllerCreationParams params;
    if (WebViewPlatform.instance is WebKitWebViewPlatform) {
      params = WebKitWebViewControllerCreationParams(
        allowsInlineMediaPlayback: true,
        mediaTypesRequiringUserAction: const {},
      );
    } else {
      params = const PlatformWebViewControllerCreationParams();
    }

    final controller = WebViewController.fromPlatformCreationParams(params);
    unawaited(controller.setJavaScriptMode(.unrestricted));
    unawaited(
      controller.addJavaScriptChannel(
        YoutubeEngineAssets.eventChannel,
        onMessageReceived: _handleMessage,
      ),
    );
    unawaited(
      controller.setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) => unawaited(_impl.onPageLoaded()),
          onNavigationRequest: _handleNavigation,
        ),
      ),
    );
    // The scroll view behind the background color only exists on iOS.
    if (defaultTargetPlatform != TargetPlatform.macOS) {
      unawaited(controller.setBackgroundColor(Colors.black));
    }

    switch (controller.platform) {
      case final AndroidWebViewController android:
        unawaited(android.setMediaPlaybackRequiresUserGesture(false));
        unawaited(android.enableZoom(false));
      case final WebKitWebViewController webKit:
        unawaited(webKit.setAllowsBackForwardNavigationGestures(false));
    }
    return controller;
  }

  Future<void> _loadEngine() async {
    final html = await rootBundle.loadString(YoutubeEngineAssets.html);
    final playerJs = await rootBundle.loadString(YoutubeEngineAssets.script);
    if (!mounted) {
      return;
    }
    await _webViewController.loadHtmlString(
      html.replaceFirst(_scriptTag, '<script>\n$playerJs\n</script>'),
      baseUrl: _baseUrl,
    );
  }

  void _handleMessage(JavaScriptMessage message) {
    final Object? decoded;
    try {
      decoded = jsonDecode(message.message);
    } on FormatException {
      return;
    }
    if (decoded is Map) {
      _impl.receiveEnginePayload(Map<String, Object?>.from(decoded));
    }
  }

  /// Cancels every navigation not required for YouTube playback.
  ///
  /// Sub-frame requests are restricted to an allowlist of YouTube/Google
  /// hosts, and *all* main-frame navigations are cancelled so taps that
  /// slip through (YouTube logo, video title, end cards) or `window.open`
  /// attempts can never leave the playback document.
  NavigationDecision _handleNavigation(NavigationRequest request) {
    final url = request.url;
    if (url == 'about:blank' || url == 'about:srcdoc') {
      return .navigate;
    }
    if (request.isMainFrame) {
      // The only permitted main-frame "navigation" is the initial document
      // load itself, which platforms report against the base URL.
      return url == _baseUrl || url == '$_baseUrl/' ? .navigate : .prevent;
    }
    final host = Uri.tryParse(url)?.host ?? '';
    final isAllowed = _allowedHosts.any(
      (allowed) => host == allowed || host.endsWith('.$allowed'),
    );
    return isAllowed ? .navigate : .prevent;
  }
}
