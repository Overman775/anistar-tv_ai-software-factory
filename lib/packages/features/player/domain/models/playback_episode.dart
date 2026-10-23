/// Immutable episode metadata available to the player for one anime.
final class PlaybackEpisode {
  final int number;
  final String title;
  final Uri? previewUri;
  final bool isWatched;

  const PlaybackEpisode({required this.number, required this.title, this.previewUri, this.isWatched = false});
}
