import '../../../catalog/domain/models/catalog_filter.dart';
import '../../domain/models/anime_details.dart';

typedef AnimeMetadataValue = ({String label, CatalogFilter? filter});

/// Match display fields to validated source links without changing their paths.
final class AnimeDetailFilterGroups {
  final List<({String heading, List<AnimeMetadataValue> values})> rows;
  final List<CatalogFilter> remaining;
  final Map<String, int> indices;

  bool get hasGroups => rows.isNotEmpty;

  List<AnimeMetadataValue> _values(String heading) =>
      rows.where((row) => row.heading == heading).firstOrNull?.values ?? const [];

  CatalogFilter? get year => _values('Год').firstOrNull?.filter;
  CatalogFilter? get director => _values('Режиссёр').firstOrNull?.filter;
  String? get directorText => director == null ? _values('Режиссёр').firstOrNull?.label : null;
  List<CatalogFilter> get genres => _values('Жанры').map((value) => value.filter).whereType<CatalogFilter>().toList();
  List<String> get genreText => [
    for (final value in _values('Жанры'))
      if (value.filter == null) value.label,
  ];

  AnimeDetailFilterGroups._(this.rows, this.remaining, this.indices);

  factory AnimeDetailFilterGroups.fromDetails(AnimeDetails details, List<CatalogFilter> filters) {
    final remaining = filters.toList();
    final indices = <String, int>{};
    for (var index = 0; index < filters.length; index++) {
      indices.putIfAbsent(filters[index].path, () => index);
    }
    final rows = <({String heading, List<AnimeMetadataValue> values})>[];

    void addRow(String heading, Iterable<String?> labels, RegExp category) {
      final values = <AnimeMetadataValue>[];
      for (final value in labels) {
        final label = value?.trim();
        if (label == null || label.isEmpty) continue;
        final normalized = _normalize(label, heading);
        final index = remaining.indexWhere(
          (filter) => category.hasMatch(filter.path) && _normalize(filter.label, heading) == normalized,
        );
        values.add((label: label, filter: index < 0 ? null : remaining.removeAt(index)));
      }
      if (values.isNotEmpty) rows.add((heading: heading, values: values));
    }

    addRow('Год', [details.year], _yearPath);
    addRow('Жанры', details.genres, _genrePath);
    addRow('Режиссёр', [details.director], _directorPath);
    addRow('Автор', [details.author], _authorPath);

    return AnimeDetailFilterGroups._(List.unmodifiable(rows), List.unmodifiable(remaining), Map.unmodifiable(indices));
  }

  static final _yearPath = _fieldPath('year');
  static final _directorPath = _fieldPath('director');
  static final _authorPath = _fieldPath('author');
  static final _genrePath = RegExp(
    r'^/(?:filter/janrs/(?:[a-zA-Z0-9+_-]|%(?:[89a-fA-F][a-fA-F0-9]|20))+|anime/[a-z][a-z0-9-]*)/$',
  );

  static RegExp _fieldPath(String field) =>
      RegExp('^/filter/$field/${r'(?:[a-zA-Z0-9+_-]|%(?:[89a-fA-F][a-fA-F0-9]|20))+/$'}');

  static String _normalize(String value, String heading) {
    final normalized = value.trim().toLowerCase().replaceAll('ё', 'е').replaceAll(RegExp(r'\s+'), ' ');
    final field = heading.toLowerCase().replaceAll('ё', 'е');

    return normalized.replaceFirst(RegExp('^$field\\s*:\\s*'), '');
  }
}
