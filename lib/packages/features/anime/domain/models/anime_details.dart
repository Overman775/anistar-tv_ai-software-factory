import '../../../catalog/domain/models/catalog_filter.dart';
import 'anime_part.dart';

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
  final double? rating;
  final String? director;
  final String? updateMessage;
  final String? publicationDate;
  final List<AnimePart> parts;

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
    this.rating,
    this.director,
    this.updateMessage,
    this.publicationDate,
    List<AnimePart> parts = const [],
  }) : genres = List.unmodifiable(genres),
       filters = List.unmodifiable(filters),
       parts = List.unmodifiable(parts);
}
