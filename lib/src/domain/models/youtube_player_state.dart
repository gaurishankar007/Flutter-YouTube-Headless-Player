/// The playback state of the underlying YouTube IFrame player.
///
/// Mirrors the `YT.PlayerState` constants of the IFrame Player API, plus
/// [unknown] for the time before the player has reported anything.
enum YoutubePlayerState(
  /// The raw `YT.PlayerState` integer constant.
  final int code,
) {
  /// No state has been reported by the player yet.
  unknown(-2),

  /// The player is loaded but playback has not started (`UNSTARTED`).
  idle(-1),

  /// Playback finished (`ENDED`).
  ended(0),

  /// The video is currently playing (`PLAYING`).
  playing(1),

  /// Playback is paused (`PAUSED`).
  paused(2),

  /// The player is buffering (`BUFFERING`).
  buffering(3),

  /// A video is cued and ready to play (`CUED`).
  cued(5);

  /// Resolves the state matching a raw IFrame API [code].
  ///
  /// Returns [unknown] for unrecognized codes.
  static YoutubePlayerState fromCode(int code) {
    for (final state in values) {
      if (state.code == code) {
        return state;
      }
    }
    return unknown;
  }
}
