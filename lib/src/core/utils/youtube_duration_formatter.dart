/// Formats a [duration] as `m:ss` or `h:mm:ss` for time labels.
String formatYoutubeDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  final seconds = duration.inSeconds.remainder(60);
  final paddedSeconds = seconds.toString().padLeft(2, '0');
  if (hours > 0) {
    final paddedMinutes = minutes.toString().padLeft(2, '0');
    return '$hours:$paddedMinutes:$paddedSeconds';
  }
  return '$minutes:$paddedSeconds';
}
