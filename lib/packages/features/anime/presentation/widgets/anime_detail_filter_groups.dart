import '../../../catalog/domain/models/catalog_filter.dart';
import '../../domain/models/anime_details.dart';

/// Presentation-only grouping keeps site links beside their matching metadata.
final class AnimeDetailFilterGroups {
  final CatalogFilter? year;
  final List<CatalogFilter> genres;
  final List<String> genreText;
  final CatalogFilter? director;
  final String? directorText;
  final List<CatalogFilter> remaining;
  final Map<String, int> indices;

  bool get hasGroups =>
      genres.isNotEmpty || genreText.isNotEmpty || director != null || directorText != null || remaining.isNotEmpty;

  AnimeDetailFilterGroups._({
    required this.year,
    required this.genres,
    required this.genreText,
    required this.director,
    required this.directorText,
    required this.remaining,
    required this.indices,
  });

  factory AnimeDetailFilterGroups.fromDetails(AnimeDetails details, List<CatalogFilter> filters) {
    final remaining = filters.toList(growable: true);
    final indices = <String, int>{};
    for (var index = 0; index < filters.length; index++) {
      indices.putIfAbsent(filters[index].path, () => index);
    }

    CatalogFilter? take(String? value, {bool director = false}) {
      final normalizedValue = _normalize(value, stripDirectorPrefix: director);
      if (normalizedValue.isEmpty) {
        return null;
      }
      final index = remaining.indexWhere(
        (filter) => _normalize(filter.label, stripDirectorPrefix: director) == normalizedValue,
      );
      if (index < 0) {
        return null;
      }

      return remaining.removeAt(index);
    }

    final year = take(details.year);
    final genres = <CatalogFilter>[];
    final genreText = <String>[];
    for (final genre in details.genres) {
      final filter = take(genre);
      if (filter == null) {
        genreText.add(genre);
      } else {
        genres.add(filter);
      }
    }
    final director = take(details.director, director: true);

    return AnimeDetailFilterGroups._(
      year: year,
      genres: List.unmodifiable(genres),
      genreText: List.unmodifiable(genreText),
      director: director,
      directorText: director == null ? details.director : null,
      remaining: List.unmodifiable(remaining),
      indices: Map.unmodifiable(indices),
    );
  }

  static String _normalize(String? value, {bool stripDirectorPrefix = false}) {
    var normalized = value?.trim().toLowerCase().replaceAll('ё', 'е') ?? '';
    if (stripDirectorPrefix) {
      normalized = normalized.replaceFirst(RegExp(r'^режис[сс]?ер\s*:\s*'), '');
    }

    return normalized;
  }
}
