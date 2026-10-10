final class AnimeEpisode {
  final int number;
  final bool isWatched;
  final Uri? previewUri;
  final String title;

  const AnimeEpisode({required this.number, required this.title, this.previewUri, this.isWatched = false});
}
