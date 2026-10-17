/// Playback quality levels understood by the YouTube IFrame Player API.
///
/// Note: modern YouTube players choose the quality adaptively; the API
/// treats quality requests as a hint only. `YoutubePlayerController`'s
/// `setPlaybackQuality` is therefore best-effort, while quality *change*
/// events remain reliable.
enum YoutubeQuality(
  /// The raw quality identifier used on the wire by the IFrame API.
  final String code,

  /// A short human readable label suitable for quality menus.
  final String label,
) {
  /// Let YouTube pick the quality automatically (`default`).
  auto('default', 'Auto'),

  /// 144p (`tiny`).
  tiny('tiny', '144p'),

  /// 240p (`small`).
  small('small', '240p'),

  /// 360p (`medium`).
  medium('medium', '360p'),

  /// 480p (`large`).
  large('large', '480p'),

  /// 720p HD (`hd720`).
  hd720('hd720', '720p'),

  /// 1080p HD (`hd1080`).
  hd1080('hd1080', '1080p'),

  /// 1440p HD (`hd1440`).
  hd1440('hd1440', '1440p'),

  /// 2160p / 4K (`hd2160`).
  hd2160('hd2160', '4K'),

  /// Above 4K (`highres`).
  highres('highres', '4K+');

  /// Resolves the quality matching a raw IFrame API [code].
  ///
  /// Returns [auto] for unrecognized codes.
  static YoutubeQuality fromCode(String? code) {
    for (final quality in values) {
      if (quality.code == code) {
        return quality;
      }
    }
    return auto;
  }
}
