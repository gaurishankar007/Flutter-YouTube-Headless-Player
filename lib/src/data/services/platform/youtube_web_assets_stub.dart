/// Non-web stub of the asset URL resolver.
///
/// Android/iOS load the engine document via `loadData`, so this is never
/// called there. The web variant lives in `youtube_web_assets_web.dart`
/// and is selected via a conditional import in `youtube_webview.dart`.
String resolveYoutubeAssetUrl(String assetPath) => assetPath;
