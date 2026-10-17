/// Thumbnail resolutions served by YouTube's image CDN (`i3.ytimg.com`).
///
/// Not every video provides every resolution — [max] in particular only
/// exists for videos uploaded in HD; the CDN returns a 404 placeholder for
/// missing ones. [standard] and below are always available.
enum YoutubeThumbnailQuality(
  /// The file name used by the thumbnail CDN for this resolution.
  final String code,
) {
  /// 120 × 90 (`default`).
  low('default'),

  /// 320 × 180 (`mqdefault`).
  medium('mqdefault'),

  /// 480 × 360 (`hqdefault`).
  high('hqdefault'),

  /// 640 × 480 (`sddefault`).
  standard('sddefault'),

  /// 1280 × 720 (`maxresdefault`).
  max('maxresdefault'),
}
