import 'package:flutter/foundation.dart';
import 'package:youtube_headless_player/src/core/constants/youtube_playback_rate.dart';
import 'package:youtube_headless_player/src/domain/models/youtube_player_state.dart';
import 'package:youtube_headless_player/src/domain/models/youtube_quality.dart';

/// An immutable snapshot of the player's state.
///
/// Follows the `VideoPlayerValue` idiom from Flutter's video_player: the
/// value itself is immutable, and `YoutubePlayerController` is the
/// `ValueNotifier<YoutubePlayerValue>` that publishes change notifications.
@immutable
class const YoutubePlayerValue({
  /// Whether the underlying IFrame player finished initializing.
  final bool isReady = false,

  /// The raw playback state reported by the player.
  final YoutubePlayerState playerState = .unknown,

  /// The id of the currently loaded or cued video, if any.
  final String? videoId,

  /// Current playback position.
  final Duration position = .zero,

  /// Total duration of the current video ([Duration.zero] until known).
  final Duration duration = .zero,

  /// Fraction of the video that is buffered, from `0.0` to `1.0`.
  final double bufferedFraction = 0,

  /// Player volume, from `0` to `100`.
  final int volume = 100,

  /// Whether the player is muted.
  final bool isMuted = false,

  /// Current playback rate (`1.0` is normal speed).
  final double playbackRate = YoutubePlaybackRate.normal,

  /// Playback rates supported by the current video.
  final List<double> availablePlaybackRates = const [],

  /// Current playback quality.
  final YoutubeQuality quality = .auto,

  /// Quality levels available for the current video (empty until the
  /// player reports them, typically once playback starts).
  final List<YoutubeQuality> availableQualities = const [],

  /// Whether closed captions are enabled (they only render for videos
  /// that provide or auto-generate a caption track).
  final bool captionsEnabled = false,

  /// Whether Flutter-side fullscreen mode is active.
  final bool isFullscreen = false,

  /// The last error code, or `null` when no error occurred.
  final int? errorCode,

  /// The last error message, or `null` when no error occurred.
  final String? errorMessage,

  /// Whether an autoplay is currently in flight and hasn't yet been
  /// confirmed by a `playing`, `paused`, or error event.
  ///
  /// True from the moment the player becomes ready (when the controller
  /// was constructed with `autoPlay: true`) or from
  /// `YoutubePlayerController.loadVideo`/`loadNewVideo` (which always
  /// autoplay, per the underlying `loadVideoById` API), until the engine
  /// reports the new video's real state. Distinguishes "still starting
  /// up" from "genuinely paused": the player can briefly sit in
  /// [YoutubePlayerState.unknown]/[YoutubePlayerState.idle] while an
  /// autoplaying video is still loading (both the very first video and
  /// any subsequent one loaded into the same player), which otherwise
  /// looks identical to a user-paused video.
  final bool isPendingAutoplay = false,
}) {
  /// Creates a state snapshot.
  this;

  /// Whether the video is currently playing.
  bool get isPlaying => playerState == .playing;

  /// Whether playback is paused.
  bool get isPaused => playerState == .paused;

  /// Whether the player is buffering.
  bool get isBuffering => playerState == .buffering;

  /// Whether playback reached the end of the video.
  bool get hasEnded => playerState == .ended;

  /// Whether the player reported an error.
  bool get hasError => errorCode != null;

  /// The buffered amount expressed as a position on the timeline.
  Duration get bufferedPosition => duration * bufferedFraction;

  /// Creates a copy of this value with the given fields replaced.
  ///
  /// [errorCode] and [errorMessage] are always taken from the arguments so
  /// a subsequent successful event clears a previous error.
  YoutubePlayerValue copyWith({
    bool? isReady,
    YoutubePlayerState? playerState,
    String? videoId,
    Duration? position,
    Duration? duration,
    double? bufferedFraction,
    int? volume,
    bool? isMuted,
    double? playbackRate,
    List<double>? availablePlaybackRates,
    YoutubeQuality? quality,
    List<YoutubeQuality>? availableQualities,
    bool? captionsEnabled,
    bool? isFullscreen,
    int? errorCode,
    String? errorMessage,
    bool? isPendingAutoplay,
  }) {
    return YoutubePlayerValue(
      isReady: isReady ?? this.isReady,
      playerState: playerState ?? this.playerState,
      videoId: videoId ?? this.videoId,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      bufferedFraction: bufferedFraction ?? this.bufferedFraction,
      volume: volume ?? this.volume,
      isMuted: isMuted ?? this.isMuted,
      playbackRate: playbackRate ?? this.playbackRate,
      availablePlaybackRates:
          availablePlaybackRates ?? this.availablePlaybackRates,
      quality: quality ?? this.quality,
      availableQualities: availableQualities ?? this.availableQualities,
      captionsEnabled: captionsEnabled ?? this.captionsEnabled,
      isFullscreen: isFullscreen ?? this.isFullscreen,
      errorCode: errorCode,
      errorMessage: errorMessage,
      isPendingAutoplay: isPendingAutoplay ?? this.isPendingAutoplay,
    );
  }

  @override
  String toString() {
    return 'YoutubePlayerValue('
        'isReady: $isReady, '
        'playerState: $playerState, '
        'videoId: $videoId, '
        'position: $position, '
        'duration: $duration, '
        'bufferedFraction: $bufferedFraction, '
        'volume: $volume, '
        'isMuted: $isMuted, '
        'playbackRate: $playbackRate, '
        'quality: $quality, '
        'isFullscreen: $isFullscreen, '
        'errorCode: $errorCode)';
  }
}
