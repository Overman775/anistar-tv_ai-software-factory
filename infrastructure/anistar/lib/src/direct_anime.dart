final class DirectAnime {
  final String? description;
  final List<String> genres;
  final int id;
  final bool? isFavorite;
  final bool isOngoing;
  final Uri? posterUri;
  final String? seriesInfo;
  final String slug;
  final String title;
  final String? voiceover;
  final String? year;

  const DirectAnime({
    required this.id,
    required this.slug,
    required this.title,
    this.posterUri,
    this.isFavorite,
    this.year,
    this.genres = const [],
    this.voiceover,
    this.seriesInfo,
    this.description,
    this.isOngoing = false,
  });
}
