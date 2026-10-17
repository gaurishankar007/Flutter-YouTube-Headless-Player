import 'package:youtube_headless_player/src/core/constants/youtube_thumbnail_quality.dart';

/// Builds the URL of the thumbnail image YouTube hosts for [videoId].
///
/// [webp] selects the WebP variant (smaller files); pass `false` for JPEG
/// when the consumer cannot decode WebP.
String youtubeThumbnailUrl({
  required String videoId,
  YoutubeThumbnailQuality quality = .standard,
  bool webp = true,
}) {
  return webp
      ? 'https://i3.ytimg.com/vi_webp/$videoId/${quality.code}.webp'
      : 'https://i3.ytimg.com/vi/$videoId/${quality.code}.jpg';
}
