import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Applies and restores the platform side effects of fullscreen playback.
///
/// Fullscreen is controlled entirely by Flutter — the browser fullscreen
/// API and the YouTube fullscreen button are never used. This manager only
/// handles the system chrome; the actual layout change (expanding the
/// player to cover the screen) is the responsibility of the hosting widget
/// tree, driven by `YoutubePlayerValue.isFullscreen`.
abstract final class YoutubeFullscreenManager {
  /// Restores the app's own orientation lock on [exit], instead of
  /// re-enabling every device orientation.
  ///
  /// Set this once at startup when the app restricts orientations globally.
  static Future<void> Function()? restoreOrientations;

  /// Hides the system UI and locks the device to [orientations].
  ///
  /// No-op on web, where there is no system chrome to hide; web apps
  /// simply react to `isFullscreen` by expanding the player layout.
  static Future<void> enter({
    List<DeviceOrientation> orientations = const [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ],
  }) async {
    if (kIsWeb) {
      return;
    }
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    await SystemChrome.setPreferredOrientations(orientations);
  }

  /// Restores the system UI and the orientations via [restoreOrientations],
  /// or re-enables every device orientation when it isn't set.
  static Future<void> exit() async {
    if (kIsWeb) {
      return;
    }
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    final restore = restoreOrientations;
    if (restore != null) {
      await restore();
    } else {
      await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    }
  }
}
