import '../../../catalog/domain/models/catalog_filter.dart';

final class AnimeDetails {
  final String? description;
  final List<String> genres;
  final List<CatalogFilter> filters;
  final int id;
  final bool? isFavorite;
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
    this.filters = const [],
    this.description,
    this.isFavorite,
    this.posterUri,
    this.seriesInfo,
    this.voiceover,
    this.year,
  });
}
