final class AnimeSummary {
  final double? rating;
  final int id;
  final bool? isFavorite;
  final Uri? posterUri;
  final String slug;
  final String title;
  final String? year;

  const AnimeSummary({
    required this.id,
    required this.slug,
    required this.title,
    this.posterUri,
    this.rating,
    this.year,
    this.isFavorite,
  });
}
