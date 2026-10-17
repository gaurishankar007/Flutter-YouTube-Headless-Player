import 'package:material_ui/material_ui.dart';

/// Color scheme of a `YoutubeProgressBar`.
@immutable
class YoutubeProgressBarColors {
  /// Creates a progress bar color scheme.
  const YoutubeProgressBarColors({
    this.played = const Color(0xFFFF0000),
    this.buffered = const Color(0x61FFFFFF),
    this.background = const Color(0x3DFFFFFF),
    this.thumb = const Color(0xFFFF0000),
  });

  /// Color of the already-played portion of the track.
  final Color played;

  /// Color of the buffered portion of the track.
  final Color buffered;

  /// Color of the remaining track.
  final Color background;

  /// Color of the draggable thumb.
  final Color thumb;
}
