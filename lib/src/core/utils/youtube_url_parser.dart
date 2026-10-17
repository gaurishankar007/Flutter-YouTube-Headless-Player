/// The character class and length of a YouTube video id.
const String _videoIdPattern = r'[_\-a-zA-Z0-9]{11}';

/// URL shapes a video id can be extracted from.
final List<RegExp> _videoUrlPatterns = [
  // youtube.com/watch?v=ID (v may appear after other query parameters)
  RegExp('youtube(?:-nocookie)?\\.com/watch\\?(?:.*&)?v=($_videoIdPattern)'),
  // youtube.com/embed/ID, /shorts/ID, /live/ID, /v/ID
  RegExp(
    'youtube(?:-nocookie)?\\.com/(?:embed|shorts|live|v)/($_videoIdPattern)',
  ),
  // youtu.be/ID
  RegExp('youtu\\.be/($_videoIdPattern)'),
];

/// Extracts the 11-character video id from any common YouTube URL form.
///
/// Supported: `watch?v=`, `youtu.be/`, `embed/`, `shorts/`, `live/` and
/// `/v/` URLs — with or without scheme, `www.`/`m.` subdomain, extra query
/// parameters, or the privacy-enhanced `youtube-nocookie.com` host. A bare
/// video id is passed through unchanged.
///
/// Returns `null` when no id can be found.
String? youtubeVideoIdFromUrl(String url) {
  final trimmed = url.trim();
  if (RegExp('^$_videoIdPattern\$').hasMatch(trimmed)) {
    return trimmed;
  }
  for (final pattern in _videoUrlPatterns) {
    final match = pattern.firstMatch(trimmed);
    if (match != null) {
      return match.group(1);
    }
  }
  return null;
}
