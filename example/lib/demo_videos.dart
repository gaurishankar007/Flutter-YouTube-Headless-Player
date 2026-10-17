/// A sample video the demos can switch between.
///
/// Holds YouTube URLs in different forms on purpose (bare id, `youtu.be`,
/// `embed`) to exercise the package's URL parsing.
class DemoVideo {
  /// Creates a demo video entry.
  const DemoVideo(this.url, this.title);

  /// Any YouTube URL form, or a bare video id.
  final String url;

  /// Human-readable title shown in the video list.
  final String title;
}

/// Videos shared by every demo screen.
const List<DemoVideo> demoVideos = [
  DemoVideo(
    'hdkuSz4MbDI',
    'Kirtans From The Sacred Forest { Kirtan 3 } Agnideva Dasa Prabhu',
  ),
  DemoVideo(
    'https://youtu.be/kfhcWQpl9v4',
    'Jai Govinda Jai Gopala ~ Vaiyasaki Dasa',
  ),
  DemoVideo(
    'https://www.youtube.com/embed/K6hfp4227bA',
    'Kirtans From The Sacred Forest { Kirtan 1 } Agnideva Dasa Prabhu',
  ),
];
