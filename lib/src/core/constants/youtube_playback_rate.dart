/// The playback rates commonly supported by the YouTube IFrame Player API.
///
/// The set of rates actually supported for a given video is reported by the
/// player itself and exposed through `YoutubePlayerValue.availablePlaybackRates`;
/// [all] is the conventional fallback when that list is empty.
abstract final class YoutubePlaybackRate {
  /// Quarter speed.
  static const double quarter = 0.25;

  /// Half speed.
  static const double half = 0.5;

  /// Three-quarter speed.
  static const double threeQuarter = 0.75;

  /// Normal speed.
  static const double normal = 1;

  /// One-and-a-quarter speed.
  static const double oneAndAQuarter = 1.25;

  /// One-and-a-half speed.
  static const double oneAndAHalf = 1.5;

  /// One-and-three-quarter speed.
  static const double oneAndThreeQuarter = 1.75;

  /// Double speed.
  static const double double_ = 2;

  /// Every conventional playback rate, slowest first.
  static const List<double> all = [
    quarter,
    half,
    threeQuarter,
    normal,
    oneAndAQuarter,
    oneAndAHalf,
    oneAndThreeQuarter,
    double_,
  ];

  /// Formats a [rate] for display, e.g. `1x`, `1.5x`.
  static String label(double rate) {
    final isWhole = rate == rate.roundToDouble();
    return isWhole ? '${rate.round()}x' : '${rate}x';
  }
}
