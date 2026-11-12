import 'package:html/parser.dart' as html;

import 'anistar_failure.dart';
import 'contract/anistar_catalog_sort.dart';

final class HtmlCatalogParameters {
  static final _sortHandler = RegExp(
    r'''^\s*(?:return\s+)?dle_change_sort\(\s*(['"])(date|rating|news_read|comm_num|title)\1\s*,\s*(['"])(asc|desc)\3\s*\)\s*;?(?:\s*return\s+false\s*;?)?\s*$''',
  );
  static const _sortCookieNames = {
    'dle_sort_cat',
    'dle_direction_cat',
    'dle_sort_xfsearch',
    'dle_direction_xfsearch',
    'dle_no_cache',
  };

  final AnistarCatalogSort sort;

  String get field => switch (sort.criterion) {
    AnistarSortCriterion.date => 'date',
    AnistarSortCriterion.rating => 'rating',
    AnistarSortCriterion.views => 'news_read',
    AnistarSortCriterion.comments => 'comm_num',
    AnistarSortCriterion.title => 'title',
  };

  const HtmlCatalogParameters(this.sort);

  Map<String, String> cookies(String path) {
    final suffix = path.startsWith('/filter/') ? 'xfsearch' : 'cat';

    return {'dle_sort_$suffix': field, 'dle_direction_$suffix': sort.ascending ? 'asc' : 'desc', 'dle_no_cache': '1'};
  }

  void verify(String source) {
    final active = html.parse(source).querySelectorAll('form#news_set_sort a.sort-actv');
    final handler = active.length == 1 ? active.single.attributes['onclick'] : null;
    final match = _sortHandler.firstMatch(handler ?? '');
    final opposite = sort.ascending ? 'desc' : 'asc';
    if (match?.group(2) != field || match?.group(4) != opposite) {
      throw const AnistarFailure(message: 'AniStar не подтвердил выбранную сортировку. Повторите запрос.');
    }
  }

  static bool isSortCookie(String name) => _sortCookieNames.contains(name);

  static bool isValidPath(String path) => RegExp(
    r'^/(?:[a-z][a-z0-9-]*/|anime/[a-z][a-z0-9-]*/|filter/(?:janrs|year|director|author)/(?:[a-zA-Z0-9+_-]|%(?:[89a-fA-F][a-fA-F0-9]|20))+/)$',
  ).hasMatch(path);
}
