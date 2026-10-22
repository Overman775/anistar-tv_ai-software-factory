import 'package:html/parser.dart' as html;

import 'anistar_failure.dart';
import 'contract/anistar_catalog_sort.dart';

final class HtmlCatalogParameters {
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
    final active = html.parse(source).querySelector('form#news_set_sort a.sort-actv');
    final opposite = sort.ascending ? 'desc' : 'asc';
    if (active?.attributes['onclick']?.contains("dle_change_sort('$field','$opposite')") != true) {
      throw const AnistarFailure(message: 'AniStar не подтвердил выбранную сортировку. Повторите запрос.');
    }
  }

  static bool isValidPath(String path) => RegExp(
    r'^/(?:[a-z][a-z0-9-]*/|anime/[a-z][a-z0-9-]*/|filter/(?:janrs|year|director)/(?:[a-zA-Z0-9+_-]|%(?:[89a-fA-F][a-fA-F0-9]|20))+/)$',
  ).hasMatch(path);
}
