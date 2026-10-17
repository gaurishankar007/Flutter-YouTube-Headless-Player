import 'dart:ui_web' as ui_web;

import 'package:web/web.dart' as web;

/// Web implementation of the asset URL resolver.
///
/// Resolves a bundled asset to an absolute URL using the engine's own
/// asset manager and the document's `<base href>`. This is deliberately
/// **not** based on `Uri.base`: with a path URL strategy (as used by
/// routed apps), `Uri.base` is the *current route* URL, and resolving
/// against it produces a non-existent path like
/// `/dashboard/assets/packages/...`. SPA hosting then serves the app's
/// own `index.html` into the player iframe, and the app's router renders
/// its not-found page inside the player.
String resolveYoutubeAssetUrl(String assetPath) {
  final assetUrl = ui_web.assetManager.getAssetUrl(assetPath);
  return Uri.parse(web.document.baseURI).resolve(assetUrl).toString();
}
