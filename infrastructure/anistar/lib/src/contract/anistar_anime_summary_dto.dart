/// Catalog projection. Null favorite means unknown; zero is a valid rating.
/// Slug retains the existing site identifier and route format.
final class AnistarAnimeSummaryDto {
  final int id;
  final String slug;
  final String title;
  final Uri? posterUri;
  final String? year;
  final double? rating;
  final bool? isFavorite;

  const AnistarAnimeSummaryDto({
    required this.id,
    required this.slug,
    required this.title,
    this.posterUri,
    this.year,
    this.rating,
    this.isFavorite,
  });
}
