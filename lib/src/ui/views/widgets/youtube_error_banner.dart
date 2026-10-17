import 'package:material_ui/material_ui.dart';

/// Error message shown over the video when playback fails.
class const YoutubeErrorBanner({
  /// The error description; a generic message is shown when `null`.
  final String? message,
  super.key,
}) extends StatelessWidget {
  /// Creates an error banner with an optional [message].
  this;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: Colors.white,
              size: 40,
            ),
            const SizedBox(height: 8),
            Text(
              message ?? 'Playback failed.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}
