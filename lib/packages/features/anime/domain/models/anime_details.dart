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

  AnimeDetails({
    required this.id,
    required this.slug,
    required this.title,
    required List<String> genres,
    required this.isOngoing,
    List<CatalogFilter> filters = const [],
    this.description,
    this.isFavorite,
    this.posterUri,
    this.seriesInfo,
    this.voiceover,
    this.year,
  }) : genres = List.unmodifiable(genres),
       filters = List.unmodifiable(filters);
}
