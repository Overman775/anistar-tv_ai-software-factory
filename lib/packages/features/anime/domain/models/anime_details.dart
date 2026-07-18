final class AnimeDetails {
  final String? description;
  final List<String> genres;
  final int id;
  final bool isOngoing;
  final Uri? posterUri;
  final String? seriesInfo;
  final String slug;
  final String title;
  final String? voiceover;
  final String? year;

  const AnimeDetails({
    required this.id,
    required this.slug,
    required this.title,
    required this.genres,
    required this.isOngoing,
    this.description,
    this.posterUri,
    this.seriesInfo,
    this.voiceover,
    this.year,
  });
}
