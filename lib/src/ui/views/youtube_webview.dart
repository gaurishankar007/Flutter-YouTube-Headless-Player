import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:material_ui/material_ui.dart';
import 'package:youtube_headless_player/src/data/services/platform/youtube_web_assets_stub.dart'
    if (dart.library.js_interop) 'package:youtube_headless_player/src/data/services/platform/youtube_web_assets_web.dart';
import 'package:youtube_headless_player/src/ui/controllers/youtube_controller_impl.dart';
import 'package:youtube_headless_player/src/ui/controllers/youtube_player_controller.dart';

/// The headless WebView hosting the YouTube IFrame playback engine.
///
/// Renders no chrome of its own and is expected to sit behind an
/// `IgnorePointer` — every user interaction is handled by Flutter widgets
/// layered on top.
///
/// Loading strategy:
/// - **Android / iOS**: `index.html` and `player.js` are read from the
///   package assets, the script tag is inlined, and the document is loaded
///   with `https://www.youtube.com` as base URL so the IFrame API sees a
///   proper origin (required for embed-restricted videos).
/// - **Web**: the asset is loaded by URL from the app's own origin, so the
///   relative `player.js` reference and the JavaScript bridge both work.
@internal
class const YoutubeWebView({
  /// The controller whose engine lives inside this WebView.
  required final YoutubePlayerController controller,
  super.key,
}) extends StatefulWidget {
  /// Creates the WebView host bound to [controller].
  this;

  @override
  State<YoutubeWebView> createState() => _YoutubeWebViewState();
}

class _YoutubeWebViewState extends State<YoutubeWebView> {
  /// Root of the package's bundled web assets.
  static const String _assetDirectory =
      'packages/youtube_headless_player/assets/youtube';

  /// Base URL used on mobile so the engine runs under a YouTube origin.
  ///
  /// The privacy-enhanced host is what battle-tested players (e.g.
  /// youtube_player_flutter) load under; combined with *not* echoing this
  /// origin into the player vars it avoids "Video unavailable" embed errors
  /// (150/152/153) that the regular host raises for spoofed origins.
  static const String _mobileBaseUrl = 'https://youtube-nocookie.com';

  /// Script tag in `index.html` replaced by the inlined engine on mobile.
  static const String _scriptTag = '<script src="player.js"></script>';

  /// Hosts that the WebView may talk to; everything else is cancelled.
  static const List<String> _allowedHosts = [
    'youtube.com',
    'youtube-nocookie.com',
    'ytimg.com',
    'googlevideo.com',
    'google.com',
    'gstatic.com',
    'googleapis.com',
  ];

  late final Future<String> _htmlFuture = _loadInlinedHtml();

  InAppWebViewSettings get _settings {
    return InAppWebViewSettings(
      allowsInlineMediaPlayback: true,
      mediaPlaybackRequiresUserGesture: false,
      disableContextMenu: true,
      supportZoom: false,
      disableHorizontalScroll: true,
      disableVerticalScroll: true,
      allowsBackForwardNavigationGestures: false,
      useShouldOverrideUrlLoading: !kIsWeb,
      // Web-only: permissions granted to the hosting iframe.
      iframeAllow: 'autoplay; encrypted-media; picture-in-picture',
      iframeAllowFullscreen: false,
    );
  }

  @override
  void dispose() {
    youtubeControllerImplOf(widget.controller).detachWebView();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return _buildWebView(initialUrlRequest: URLRequest(url: _webAssetUrl()));
    }
    return FutureBuilder<String>(
      future: _htmlFuture,
      builder: (context, snapshot) {
        final html = snapshot.data;
        if (html == null) {
          return const SizedBox.expand();
        }
        return _buildWebView(
          initialData: InAppWebViewInitialData(
            data: html,
            baseUrl: WebUri(_mobileBaseUrl),
            historyUrl: WebUri(_mobileBaseUrl),
          ),
        );
      },
    );
  }

  Widget _buildWebView({
    URLRequest? initialUrlRequest,
    InAppWebViewInitialData? initialData,
  }) {
    return InAppWebView(
      initialUrlRequest: initialUrlRequest,
      initialData: initialData,
      initialSettings: _settings,
      onWebViewCreated: (webViewController) {
        youtubeControllerImplOf(widget.controller)
            .attachWebView(webViewController);
      },
      onLoadStop: (webViewController, url) async {
        await youtubeControllerImplOf(widget.controller).onPageLoaded();
      },
      shouldOverrideUrlLoading: _handleNavigation,
      onCreateWindow: (webViewController, createWindowAction) async {
        // Block every popup (e.g. "Watch on YouTube" attempts).
        return false;
      },
    );
  }

  /// Cancels every navigation not required for YouTube playback.
  ///
  /// Sub-frame requests are restricted to an allowlist of YouTube/Google
  /// hosts, and *all* main-frame navigations are cancelled so taps that
  /// slip through (YouTube logo, video title, end cards) can never leave
  /// the playback document.
  Future<NavigationActionPolicy> _handleNavigation(
    InAppWebViewController webViewController,
    NavigationAction navigationAction,
  ) async {
    final url = navigationAction.request.url;
    if (url == null) {
      return NavigationActionPolicy.CANCEL;
    }
    if (url.toString() == 'about:blank' || url.toString() == 'about:srcdoc') {
      return NavigationActionPolicy.ALLOW;
    }
    if (navigationAction.isForMainFrame) {
      // The only permitted main-frame "navigation" is the initial document
      // load itself, which some platforms report against the base URL.
      return url.toString() == _mobileBaseUrl ||
              url.toString() == '$_mobileBaseUrl/'
          ? NavigationActionPolicy.ALLOW
          : NavigationActionPolicy.CANCEL;
    }
    return _isAllowedHost(url.host)
        ? NavigationActionPolicy.ALLOW
        : NavigationActionPolicy.CANCEL;
  }

  bool _isAllowedHost(String host) {
    for (final allowed in _allowedHosts) {
      if (host == allowed || host.endsWith('.$allowed')) {
        return true;
      }
    }
    return false;
  }

  /// Reads the bundled HTML and inlines `player.js` in place of its script
  /// tag, producing a single self-contained document for `loadData`.
  Future<String> _loadInlinedHtml() async {
    final html = await rootBundle.loadString('$_assetDirectory/index.html');
    final playerJs = await rootBundle.loadString('$_assetDirectory/player.js');
    return html.replaceFirst(_scriptTag, '<script>\n$playerJs\n</script>');
  }

  /// Resolves the asset URL of `index.html` on the app's own origin (web).
  ///
  /// Resolution goes through the engine's asset manager and the document
  /// base — never `Uri.base`, which under a path URL strategy is the
  /// current route and would point the iframe at a non-existent path.
  ///
  /// The bridge's player id travels as a query parameter so the engine can
  /// tag its `postMessage` events for this specific player instance.
  WebUri _webAssetUrl() {
    final assetUrl =
        Uri.parse(resolveYoutubeAssetUrl('$_assetDirectory/index.html'))
            .replace(
              queryParameters: {
                'playerId': youtubeControllerImplOf(widget.controller).playerId,
              },
            );
    return WebUri.uri(assetUrl);
  }
}
