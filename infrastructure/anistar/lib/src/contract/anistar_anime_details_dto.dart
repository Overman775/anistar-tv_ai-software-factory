import 'anistar_anime_part_dto.dart';
import 'anistar_catalog_filter_dto.dart';

/// Details projection. Optional metadata does not make the result incomplete.
/// Null favorite means unknown. Ongoing is supplied by the adapter.
final class AnistarAnimeDetailsDto {
  final int id;
  final String slug;
  final String title;
  final Uri? posterUri;
  final String? year;
  final List<String> genres;
  final List<AnistarCatalogFilterDto> filters;
  final String? description;
  final String? voiceover;
  final String? seriesInfo;
  final bool isOngoing;
  final bool? isFavorite;
  final double? rating;
  final String? director;
  final String? updateMessage;
  final String? publicationDate;
  final List<AnistarAnimePartDto> parts;

  AnistarAnimeDetailsDto({
    required this.id,
    required this.slug,
    required this.title,
    this.posterUri,
    this.year,
    List<String> genres = const [],
    List<AnistarCatalogFilterDto> filters = const [],
    this.description,
    this.voiceover,
    this.seriesInfo,
    this.isOngoing = false,
    this.isFavorite,
    this.rating,
    this.director,
    this.updateMessage,
    this.publicationDate,
    List<AnistarAnimePartDto> parts = const [],
  }) : genres = List.unmodifiable(genres),
       filters = List.unmodifiable(filters),
       parts = List.unmodifiable(parts);
}
