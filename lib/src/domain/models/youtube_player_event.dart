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
sealed class const YoutubePlayerEvent() {
  /// Base constructor for subclasses.
  this;
}

/// The player finished initializing and is ready to receive commands.
final class const ReadyEvent({
  /// Duration of the initially loaded video, if one was provided.
  required final Duration duration,

  /// Initial volume, from `0` to `100`.
  required final int volume,

  /// Whether the player starts out muted.
  required final bool isMuted,

  /// Initial playback rate.
  required final double playbackRate,

  /// Playback rates supported by the current video.
  required final List<double> availablePlaybackRates,

  /// Quality levels available for the current video (often empty until
  /// playback starts).
  final List<YoutubeQuality> availableQualities = const [],
}) extends YoutubePlayerEvent {
  /// Creates a ready event.
  this;
}

/// Playback started or resumed.
final class const PlayingEvent() extends YoutubePlayerEvent {
  /// Creates a playing event.
  this;
}

/// Playback was paused.
final class const PausedEvent() extends YoutubePlayerEvent {
  /// Creates a paused event.
  this;
}

/// The player is buffering.
final class const BufferingEvent() extends YoutubePlayerEvent {
  /// Creates a buffering event.
  this;
}

/// Playback reached the end of the video.
final class const EndedEvent() extends YoutubePlayerEvent {
  /// Creates an ended event.
  this;
}

/// The player returned to the unstarted/idle state (e.g. after `stop`).
final class const IdleEvent() extends YoutubePlayerEvent {
  /// Creates an idle event.
  this;
}

/// A playback error occurred.
final class const ErrorEvent({
  /// The IFrame API error code (`2`, `5`, `100`, `101`, `150`) or a
  /// negative package-internal code for bridge failures.
  required final int code,

  /// A human readable description of the error.
  required final String message,
}) extends YoutubePlayerEvent {
  /// Creates an error event.
  this;
}

/// Periodic progress snapshot, emitted every 250 ms while playing.
final class const ProgressEvent({
  /// Current playback position.
  required final Duration position,

  /// Total duration of the current video.
  required final Duration duration,

  /// Fraction of the video that is buffered, from `0.0` to `1.0`.
  required final double bufferedFraction,
}) extends YoutubePlayerEvent {
  /// Creates a progress event.
  this;

  /// The buffered amount expressed as a position on the timeline.
  Duration get bufferedPosition => duration * bufferedFraction;
}

/// The reported video duration changed (typically once metadata loads).
final class const DurationChangedEvent({
  /// The new total duration.
  required final Duration duration,
}) extends YoutubePlayerEvent {
  /// Creates a duration-changed event.
  this;
}

/// The playback quality changed.
final class const QualityChangedEvent({
  /// The new playback quality.
  required final YoutubeQuality quality,

  /// Quality levels available for the current video at this moment.
  final List<YoutubeQuality> availableQualities = const [],
}) extends YoutubePlayerEvent {
  /// Creates a quality-changed event.
  this;
}

/// The playback rate changed.
final class const PlaybackRateChangedEvent({
  /// The new playback rate.
  required final double playbackRate,
}) extends YoutubePlayerEvent {
  /// Creates a playback-rate-changed event.
  this;
}

/// The volume or mute state changed.
final class const VolumeChangedEvent({
  /// The new volume, from `0` to `100`.
  required final int volume,

  /// Whether the player is muted.
  required final bool isMuted,
}) extends YoutubePlayerEvent {
  /// Creates a volume-changed event.
  this;
}

/// Closed captions were turned on or off.
final class const CaptionsChangedEvent({
  /// Whether captions are now enabled.
  required final bool isEnabled,
}) extends YoutubePlayerEvent {
  /// Creates a captions-changed event.
  this;
}

/// Flutter-side fullscreen mode was entered or exited.
final class const FullscreenChangedEvent({
  /// Whether the player is now in fullscreen mode.
  required final bool isFullscreen,
}) extends YoutubePlayerEvent {
  /// Creates a fullscreen-changed event.
  this;
}

/// A new video started loading via `loadVideo`.
final class const VideoLoadedEvent({
  /// The id of the loaded video.
  required final String videoId,
}) extends YoutubePlayerEvent {
  /// Creates a video-loaded event.
  this;
}

/// A video was cued and is ready to play on demand.
final class const VideoCuedEvent({
  /// The id of the cued video, if the player reported one.
  required final String? videoId,
}) extends YoutubePlayerEvent {
  /// Creates a video-cued event.
  this;
}
