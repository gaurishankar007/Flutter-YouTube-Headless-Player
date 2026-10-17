import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:youtube_headless_player/src/ui/controllers/youtube_player_controller.dart';

/// Mute toggle with a hover/tap-revealed volume slider.
///
/// The slider stays collapsed until the pointer hovers over the control
/// (desktop/web) or the button is tapped once (touch); tapping while
/// revealed toggles mute — matching the YouTube web player.
///
/// On iOS (native and Safari) WebKit ignores volume changes, so the
/// control is a plain mute/unmute button there; see [showSlider].
class const YoutubeVolumeSlider({
  /// The controller to observe and act on.
  required final YoutubePlayerController controller,

  /// Width of the slider track when revealed.
  final double sliderWidth = 72,

  /// Color of the icon and slider.
  final Color color = Colors.white,

  /// Whether the volume slider is available.
  ///
  /// When `null` (the default) it is available everywhere except iOS,
  /// where the button only toggles mute. Passing `true` on iOS shows a
  /// slider that has no effect.
  final bool? showSlider,
  super.key,
}) extends StatefulWidget {
  /// Creates a volume control bound to [controller].
  this;

  @override
  State<YoutubeVolumeSlider> createState() => _YoutubeVolumeSliderState();
}

class _YoutubeVolumeSliderState extends State<YoutubeVolumeSlider> {
  /// Maximum player volume accepted by the IFrame API.
  static const double _maxVolume = 100;

  /// Duration of the slider reveal/collapse animation.
  static const Duration _revealDuration = Duration(milliseconds: 150);

  bool _hovering = false;
  bool _pinnedOpen = false;

  /// Whether the slider is currently revealed. Mirrors the YouTube web
  /// player: revealed while the pointer hovers over the control, or after
  /// a tap on the button (touch devices have no hover).
  bool get _revealed => _sliderEnabled && (_hovering || _pinnedOpen);

  bool get _sliderEnabled =>
      widget.showSlider ?? defaultTargetPlatform != TargetPlatform.iOS;

  void _handleButtonPressed() {
    if (_sliderEnabled && !_revealed) {
      setState(() => _pinnedOpen = true);
      return;
    }
    final controller = widget.controller;
    if (controller.value.isMuted) {
      unawaited(controller.unMute());
    } else {
      unawaited(controller.mute());
    }
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() {
        _hovering = false;
        _pinnedOpen = false;
      }),
      child: ValueListenableBuilder(
        valueListenable: widget.controller,
        builder: (context, value, _) {
          final volumeIcon = value.isMuted || value.volume == 0
              ? Icons.volume_off_rounded
              : (value.volume < _maxVolume / 2
                    ? Icons.volume_down_rounded
                    : Icons.volume_up_rounded);
          return Row(
            mainAxisSize: .min,
            children: [
              IconButton(
                onPressed: _handleButtonPressed,
                color: widget.color,
                icon: Icon(volumeIcon),
                tooltip: _sliderEnabled && !_revealed
                    ? 'Volume'
                    : (value.isMuted ? 'Unmute' : 'Mute'),
              ),
              ClipRect(
                child: AnimatedSize(
                  duration: _revealDuration,
                  alignment: .centerLeft,
                  child: !_revealed
                      ? const SizedBox.shrink()
                      : SizedBox(
                          width: widget.sliderWidth,
                          child: SliderTheme(
                            data: SliderThemeData(
                              trackHeight: 2,
                              thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 5,
                              ),
                              overlayShape: .noOverlay,
                              activeTrackColor: widget.color,
                              thumbColor: widget.color,
                              inactiveTrackColor: widget.color.withValues(
                                alpha: 0.3,
                              ),
                            ),
                            child: Slider(
                              value: value.isMuted
                                  ? 0
                                  : value.volume.toDouble(),
                              max: _maxVolume,
                              onChanged: (volume) {
                                if (value.isMuted) {
                                  unawaited(widget.controller.unMute());
                                }
                                unawaited(
                                  widget.controller.setVolume(volume.round()),
                                );
                              },
                            ),
                          ),
                        ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
