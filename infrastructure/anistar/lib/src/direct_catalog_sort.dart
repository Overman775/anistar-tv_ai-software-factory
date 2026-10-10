import 'package:html/parser.dart' as html;

import 'anistar_failure.dart';

/// Request-local DLE ordering; never persisted in the account cookie jar.
final class DirectCatalogSort {
  final DirectSortCriterion criterion;
  final bool ascending;

  String get field => switch (criterion) {
    DirectSortCriterion.date => 'date',
    DirectSortCriterion.rating => 'rating',
    DirectSortCriterion.newsRead => 'news_read',
    DirectSortCriterion.comments => 'comm_num',
    DirectSortCriterion.title => 'title',
  };

  const DirectCatalogSort(this.criterion, {this.ascending = false});

  Map<String, String> cookies(String path) {
    final suffix = path.startsWith('/filter/janrs/') ? 'xfsearch' : 'cat';

    return {'dle_sort_$suffix': field, 'dle_direction_$suffix': ascending ? 'asc' : 'desc', 'dle_no_cache': '1'};
  }

  void verify(String source) {
    final form = html.parse(source).querySelector('form#news_set_sort');
    final active = form?.querySelector('a.sort-actv');
    final opposite = ascending ? 'desc' : 'asc';
    final expected = "dle_change_sort('$field','$opposite')";
    if (active?.attributes['onclick']?.contains(expected) != true) {
      throw const AnistarFailure(message: 'AniStar не подтвердил выбранную сортировку. Повторите запрос.');
    }
  }
}

enum DirectSortCriterion { date, rating, newsRead, comments, title }
