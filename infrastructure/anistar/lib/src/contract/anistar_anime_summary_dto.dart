import 'anistar_catalog_filter_dto.dart';

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
  final String? genreText;
  final String? description;
  final String? updateMessage;
  final String? publicationDate;
  final String? seriesInfo;
  final String? voiceover;
  final List<AnistarCatalogFilterDto> genreFilters;

  List<String> get genres => List.unmodifiable(
    genreText?.split(',').map((genre) => genre.trim()).where((genre) => genre.isNotEmpty) ?? const <String>[],
  );

  const AnistarAnimeSummaryDto({
    required this.id,
    required this.slug,
    required this.title,
    this.posterUri,
    this.year,
    this.rating,
    this.isFavorite,
    this.genreText,
    this.description,
    this.updateMessage,
    this.publicationDate,
    this.seriesInfo,
    this.voiceover,
  }) : genreFilters = const [];

  AnistarAnimeSummaryDto.withGenreFilters({
    required this.id,
    required this.slug,
    required this.title,
    required List<AnistarCatalogFilterDto> genreFilters,
    this.posterUri,
    this.rating,
    this.year,
    this.isFavorite,
    this.genreText,
    this.description,
    this.updateMessage,
    this.publicationDate,
    this.seriesInfo,
    this.voiceover,
  }) : genreFilters = List.unmodifiable(genreFilters);
}
