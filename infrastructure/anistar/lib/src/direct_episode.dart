final class DirectEpisode {
  final int number;
  final bool isWatched;
  final Uri? previewUri;
  final Map<String, Uri> sources;
  final String title;

  const DirectEpisode({
    required this.number,
    required this.title,
    required this.sources,
    this.previewUri,
    this.isWatched = false,
  });
}
