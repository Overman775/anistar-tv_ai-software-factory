import 'catalog_filter.dart';

final class AnimeSummary {
  final double? rating;
  final int id;
  final bool? isFavorite;
  final Uri? posterUri;
  final String slug;
  final String title;
  final String? year;
  final String? genreText;
  final String? description;
  final String? updateMessage;
  final String? publicationDate;
  final String? seriesInfo;
  final String? voiceover;
  final List<CatalogFilter> genreFilters;

  List<String> get genres => List.unmodifiable(
    genreText?.split(',').map((genre) => genre.trim()).where((genre) => genre.isNotEmpty) ?? const <String>[],
  );

  const AnimeSummary({
    required this.id,
    required this.slug,
    required this.title,
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
  }) : genreFilters = const [];

  AnimeSummary.withGenreFilters({
    required this.id,
    required this.slug,
    required this.title,
    required List<CatalogFilter> genreFilters,
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
