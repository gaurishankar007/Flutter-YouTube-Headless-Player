import 'package:flutter/foundation.dart';
import 'package:youtube_headless_player/src/domain/models/youtube_quality.dart';

/// Base class of every event emitted by a `YoutubePlayerController`.
///
/// The hierarchy is sealed, so consumers can exhaustively `switch` over the
/// concrete event types instead of wiring up dozens of callbacks:
///
/// ```dart
/// controller.events.listen((event) {
///   switch (event) {
///     case ProgressEvent(:final position):
///       debugPrint('at $position');
///     case EndedEvent():
///       debugPrint('done');
///     default:
///       break;
///   }
/// });
/// ```
@immutable
sealed class YoutubePlayerEvent {
  const YoutubePlayerEvent();
}

/// The player finished initializing and is ready to receive commands.
final class ReadyEvent extends YoutubePlayerEvent {
  /// Creates a ready event.
  const ReadyEvent({
    required this.duration,
    required this.volume,
    required this.isMuted,
    required this.playbackRate,
    required this.availablePlaybackRates,
    this.availableQualities = const [],
  });

  /// Duration of the initially loaded video, if one was provided.
  final Duration duration;

  /// Initial volume, from `0` to `100`.
  final int volume;

  /// Whether the player starts out muted.
  final bool isMuted;

  /// Initial playback rate.
  final double playbackRate;

  /// Playback rates supported by the current video.
  final List<double> availablePlaybackRates;

  /// Quality levels available for the current video (often empty until
  /// playback starts).
  final List<YoutubeQuality> availableQualities;
}

/// Playback started or resumed.
final class PlayingEvent extends YoutubePlayerEvent {
  /// Creates a playing event.
  const PlayingEvent();
}

/// Playback was paused.
final class PausedEvent extends YoutubePlayerEvent {
  /// Creates a paused event.
  const PausedEvent();
}

/// The player is buffering.
final class BufferingEvent extends YoutubePlayerEvent {
  /// Creates a buffering event.
  const BufferingEvent();
}

/// Playback reached the end of the video.
final class EndedEvent extends YoutubePlayerEvent {
  /// Creates an ended event.
  const EndedEvent();
}

/// The player returned to the unstarted/idle state (e.g. after `stop`).
final class IdleEvent extends YoutubePlayerEvent {
  /// Creates an idle event.
  const IdleEvent();
}

/// A playback error occurred.
final class ErrorEvent extends YoutubePlayerEvent {
  /// Creates an error event.
  const ErrorEvent({required this.code, required this.message});

  /// The IFrame API error code (`2`, `5`, `100`, `101`, `150`) or a
  /// negative package-internal code for bridge failures.
  final int code;

  /// A human readable description of the error.
  final String message;
}

/// Periodic progress snapshot, emitted every 250 ms while playing.
final class ProgressEvent extends YoutubePlayerEvent {
  /// Creates a progress event.
  const ProgressEvent({
    required this.position,
    required this.duration,
    required this.bufferedFraction,
  });

  /// Current playback position.
  final Duration position;

  /// Total duration of the current video.
  final Duration duration;

  /// Fraction of the video that is buffered, from `0.0` to `1.0`.
  final double bufferedFraction;

  /// The buffered amount expressed as a position on the timeline.
  Duration get bufferedPosition => duration * bufferedFraction;
}

/// The reported video duration changed (typically once metadata loads).
final class DurationChangedEvent extends YoutubePlayerEvent {
  /// Creates a duration-changed event.
  const DurationChangedEvent({required this.duration});

  /// The new total duration.
  final Duration duration;
}

/// The playback quality changed.
final class QualityChangedEvent extends YoutubePlayerEvent {
  /// Creates a quality-changed event.
  const QualityChangedEvent({
    required this.quality,
    this.availableQualities = const [],
  });

  /// The new playback quality.
  final YoutubeQuality quality;

  /// Quality levels available for the current video at this moment.
  final List<YoutubeQuality> availableQualities;
}

/// The playback rate changed.
final class PlaybackRateChangedEvent extends YoutubePlayerEvent {
  /// Creates a playback-rate-changed event.
  const PlaybackRateChangedEvent({required this.playbackRate});

  /// The new playback rate.
  final double playbackRate;
}

/// The volume or mute state changed.
final class VolumeChangedEvent extends YoutubePlayerEvent {
  /// Creates a volume-changed event.
  const VolumeChangedEvent({required this.volume, required this.isMuted});

  /// The new volume, from `0` to `100`.
  final int volume;

  /// Whether the player is muted.
  final bool isMuted;
}

/// Closed captions were turned on or off.
final class CaptionsChangedEvent extends YoutubePlayerEvent {
  /// Creates a captions-changed event.
  const CaptionsChangedEvent({required this.isEnabled});

  /// Whether captions are now enabled.
  final bool isEnabled;
}

/// Flutter-side fullscreen mode was entered or exited.
final class FullscreenChangedEvent extends YoutubePlayerEvent {
  /// Creates a fullscreen-changed event.
  const FullscreenChangedEvent({required this.isFullscreen});

  /// Whether the player is now in fullscreen mode.
  final bool isFullscreen;
}

/// A new video started loading via `loadVideo`.
final class VideoLoadedEvent extends YoutubePlayerEvent {
  /// Creates a video-loaded event.
  const VideoLoadedEvent({required this.videoId});

  /// The id of the loaded video.
  final String videoId;
}

/// A video was cued and is ready to play on demand.
final class VideoCuedEvent extends YoutubePlayerEvent {
  /// Creates a video-cued event.
  const VideoCuedEvent({required this.videoId});

  /// The id of the cued video, if the player reported one.
  final String? videoId;
}
