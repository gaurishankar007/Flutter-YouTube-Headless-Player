import 'package:material_ui/material_ui.dart';

/// Color scheme of a `YoutubeProgressBar`.
@immutable
class const YoutubeProgressBarColors({
  /// Color of the already-played portion of the track.
  final Color played = const Color(0xFFFF0000),

  /// Color of the buffered portion of the track.
  final Color buffered = const Color(0x61FFFFFF),

  /// Color of the remaining track.
  final Color background = const Color(0x3DFFFFFF),

  /// Color of the draggable thumb.
  final Color thumb = const Color(0xFFFF0000),
}) {
  /// Creates a progress bar color scheme.
  this;
}
