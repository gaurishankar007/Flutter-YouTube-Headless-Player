import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:youtube_headless_player/src/domain/models/youtube_player_event.dart';
import 'package:youtube_headless_player/src/ui/controllers/youtube_player_controller.dart';
import 'package:youtube_headless_player/src/ui/views/widgets/youtube_controls.dart';
import 'package:youtube_headless_player/src/ui/views/youtube_webview.dart';

/// The all-in-one YouTube player widget.
///
/// Drop it anywhere with just a controller — the `YoutubeControls` overlay
/// and fullscreen handling are built in:
///
/// ```dart
/// YoutubePlayer(controller: controller)
/// ```
///
/// **Fullscreen** is handled internally: when the controller enters
/// fullscreen (via the controls' button, `toggleFullscreen()`, etc.) the
/// player pushes a black fullscreen page on the root navigator and moves
/// itself into it *without recreating the WebView*, so playback continues
/// seamlessly. The back button/gesture pops that page and exits
/// fullscreen. No extra wiring is needed.
///
/// **Custom UIs** remain possible:
/// - Pass [controls] to replace the default overlay, or set [showControls]
///   to `false` for a bare video surface (it never receives pointer
///   events, so overlay your own widgets in a [Stack]).
/// - Set [handleFullscreen] to `false` to manage the fullscreen layout
///   yourself; keep the player in a [KeyedSubtree] with a [GlobalKey] so
///   your layout swap reparents it instead of recreating the WebView.
class YoutubePlayer extends StatefulWidget {
  /// Creates a player for [controller].
  const YoutubePlayer({
    required this.controller,
    this.fit = BoxFit.contain,
    this.aspectRatio,
    this.placeholder,
    this.loadingWidget,
    this.backgroundColor = Colors.black,
    this.onReady,
    this.showControls = true,
    this.controls,
    this.handleFullscreen = true,
    super.key,
  });

  /// The standard 16:9 video aspect ratio.
  static const double defaultAspectRatio = 16 / 9;

  /// The controller driving this player.
  final YoutubePlayerController controller;

  /// How the video surface is inscribed into the widget's bounds
  /// (e.g. [BoxFit.cover] crops instead of letterboxing).
  final BoxFit fit;

  /// The aspect ratio of the widget itself.
  ///
  /// Defaults to the controller's `videoAspectRatio`, so a portrait video
  /// renders portrait inline too.
  final double? aspectRatio;

  /// Shown instead of the video until the player is ready
  /// (e.g. a thumbnail). Takes precedence over [loadingWidget].
  final Widget? placeholder;

  /// Shown centered on top of the surface until the player is ready.
  /// Defaults to a [CircularProgressIndicator].
  final Widget? loadingWidget;

  /// Color painted behind and around the video surface.
  final Color backgroundColor;

  /// Called exactly once when the player becomes ready.
  final VoidCallback? onReady;

  /// Whether the built-in control overlay is rendered on top of the video.
  final bool showControls;

  /// Replaces the default [YoutubeControls] overlay when provided
  /// (ignored if [showControls] is `false`).
  final Widget? controls;

  /// Whether the player manages fullscreen itself by pushing a fullscreen
  /// page on the root navigator when `value.isFullscreen` becomes `true`.
  ///
  /// Set to `false` to control the fullscreen layout manually.
  final bool handleFullscreen;

  @override
  State<YoutubePlayer> createState() => _YoutubePlayerState();
}

class _YoutubePlayerState extends State<YoutubePlayer> {
  /// Preserves the player content's element identity when it moves
  /// between the inline location and the fullscreen page.
  final GlobalKey _contentKey = GlobalKey();

  StreamSubscription<YoutubePlayerEvent>? _readySubscription;
  bool _onReadyNotified = false;

  PageRouteBuilder<void>? _fullscreenRoute;
  late bool _isFullscreen = widget.controller.value.isFullscreen;

  double get _inlineAspectRatio =>
      widget.aspectRatio ?? widget.controller.videoAspectRatio;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleValueChanged);
    _watchReady();
  }

  @override
  void didUpdateWidget(YoutubePlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_handleValueChanged);
      widget.controller.addListener(_handleValueChanged);
      _isFullscreen = widget.controller.value.isFullscreen;
      _onReadyNotified = false;
      _watchReady();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleValueChanged);
    unawaited(_readySubscription?.cancel());
    _removeFullscreenRoute();
    super.dispose();
  }

  // --- Fullscreen route management -----------------------------------

  void _handleValueChanged() {
    if (!widget.handleFullscreen) {
      return;
    }
    final isFullscreen = widget.controller.value.isFullscreen;
    if (isFullscreen == _isFullscreen || !mounted) {
      return;
    }
    setState(() => _isFullscreen = isFullscreen);
    if (isFullscreen) {
      _pushFullscreenRoute();
    } else {
      _removeFullscreenRoute();
    }
  }

  void _pushFullscreenRoute() {
    // Instant transitions: the player content is reparented between the
    // inline location and the page, and animating that reads as flicker.
    final route = PageRouteBuilder<void>(
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
      pageBuilder: (context, animation, secondaryAnimation) {
        return Scaffold(
          backgroundColor: widget.backgroundColor,
          // Sized to the video itself so a portrait video fills the
          // portrait screen instead of a 16:9 box.
          body: Center(
            child: _buildContent(
              aspectRatio: widget.controller.videoAspectRatio,
            ),
          ),
        );
      },
    );
    _fullscreenRoute = route;
    final navigator = Navigator.of(context, rootNavigator: true);
    unawaited(
      navigator.push(route).then((_) {
        // Reached on any pop, including the system back gesture: make the
        // controller state (orientation, system UI) follow the route.
        if (_fullscreenRoute == route) {
          _fullscreenRoute = null;
        }
        if (widget.controller.value.isFullscreen) {
          unawaited(widget.controller.exitFullscreen());
        }
      }),
    );
  }

  void _removeFullscreenRoute() {
    final route = _fullscreenRoute;
    _fullscreenRoute = null;
    if (route != null && route.isActive) {
      // removeRoute (not pop) so an open menu/dialog pushed on top of the
      // fullscreen page can never be popped by mistake.
      route.navigator?.removeRoute(route);
    }
  }

  // --- onReady --------------------------------------------------------

  void _watchReady() {
    unawaited(_readySubscription?.cancel());
    if (widget.onReady == null) {
      return;
    }
    if (widget.controller.value.isReady) {
      _notifyReady();
      return;
    }
    _readySubscription = widget.controller.events.listen((event) {
      if (event is ReadyEvent) {
        _notifyReady();
      }
    });
  }

  void _notifyReady() {
    if (_onReadyNotified) {
      return;
    }
    _onReadyNotified = true;
    unawaited(_readySubscription?.cancel());
    _readySubscription = null;
    widget.onReady?.call();
  }

  // --- Build ----------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (widget.handleFullscreen && _isFullscreen) {
      // The content currently lives inside the fullscreen page; keep an
      // identically sized stand-in here so the page layout stays stable.
      return AspectRatio(
        aspectRatio: _inlineAspectRatio,
        child: ColoredBox(color: widget.backgroundColor),
      );
    }
    return _buildContent(aspectRatio: _inlineAspectRatio);
  }

  /// The keyed player content: video surface + pre-ready overlay
  /// + controls. Built in exactly one place per frame (inline or the
  /// fullscreen page), so the [GlobalKey] reparents instead of recreating.
  Widget _buildContent({required double aspectRatio}) {
    return KeyedSubtree(
      key: _contentKey,
      child: AspectRatio(
        aspectRatio: aspectRatio,
        child: ColoredBox(
          color: widget.backgroundColor,
          child: ClipRect(
            child: Stack(
              fit: StackFit.expand,
              children: [
                _FittedVideoSurface(
                  fit: widget.fit,
                  videoAspectRatio: widget.controller.videoAspectRatio,
                  // The WebView is a pure playback surface — it must never
                  // receive pointers; Flutter owns every gesture.
                  child: IgnorePointer(
                    child: YoutubeWebView(controller: widget.controller),
                  ),
                ),
                ValueListenableBuilder(
                  valueListenable: widget.controller,
                  builder: (context, value, _) {
                    if (value.isReady) {
                      return const SizedBox.shrink();
                    }
                    return widget.placeholder ??
                        Center(
                          child:
                              widget.loadingWidget ??
                              const CircularProgressIndicator(
                                color: Colors.white,
                              ),
                        );
                  },
                ),
                if (widget.showControls)
                  Positioned.fill(
                    child:
                        widget.controls ??
                        YoutubeControls(controller: widget.controller),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Sizes the video surface inside the available bounds according to a
/// [BoxFit] and the video's [videoAspectRatio].
class _FittedVideoSurface extends StatelessWidget {
  const _FittedVideoSurface({
    required this.fit,
    required this.videoAspectRatio,
    required this.child,
  });

  final BoxFit fit;
  final double videoAspectRatio;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bounds = constraints.biggest;
        if (bounds.isEmpty || !bounds.isFinite) {
          return child;
        }
        final videoSize = Size(videoAspectRatio, 1);
        final fitted = applyBoxFit(fit, videoSize, bounds);
        final destination = fitted.destination;
        if (destination.isEmpty) {
          return child;
        }
        return OverflowBox(
          minWidth: destination.width,
          maxWidth: destination.width,
          minHeight: destination.height,
          maxHeight: destination.height,
          child: child,
        );
      },
    );
  }
}
