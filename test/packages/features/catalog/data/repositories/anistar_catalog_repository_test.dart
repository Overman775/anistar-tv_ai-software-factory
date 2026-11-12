import 'package:anistar/anistar.dart';
import 'package:anistar_tv/packages/features/catalog/data/repositories/anistar_catalog_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../../mocks/anistar/anistar_fixtures.dart';
import '../../../../../mocks/anistar/test_anistar_client.dart';
import '../../../../../mocks/networking/html_fixture_adapter.dart';

void main() {
  test('author sort confirms each direction and preserves raw path through page two', () async {
    const path = '/filter/author/%f1%e8%ed%ee%f5%e0%f0%e0+%f2%e8%fd/';
    for (final (criterion, field) in <(AnistarSortCriterion, String)>[
      (AnistarSortCriterion.date, 'date'),
      (AnistarSortCriterion.rating, 'rating'),
      (AnistarSortCriterion.views, 'news_read'),
      (AnistarSortCriterion.comments, 'comm_num'),
      (AnistarSortCriterion.title, 'title'),
    ]) {
      for (final ascending in [false, true]) {
        final sort = AnistarCatalogSort(criterion, ascending: ascending);
        final html =
            '''
<form id="news_set_sort"><a class="sort-actv" onclick="dle_change_sort('$field','${ascending ? 'desc' : 'asc'}'); return false;">sort</a></form>
${catalogHtml.replaceAll('/anime/page/', '${path}page/')}
''';
        final adapter = HtmlFixtureAdapter({Uri.parse(path).path: html, Uri.parse('${path}page/2/').path: html});
        final dio = Dio(BaseOptions(baseUrl: 'https://v30.astar.bz/'))..httpClientAdapter = adapter;
        final client = createTestAnistarClient(dio);
        final first = await client.catalog(1, filterPath: path, sort: sort);
        expect(first.hasNext, isTrue);
        final second = await client.catalog(2, filterPath: path, sort: sort);
        expect(second.page, 2);
        expect(adapter.requests.map((request) => request.path), [path.substring(1), '${path.substring(1)}page/2/']);
        for (final request in adapter.requests) {
          expect(
            request.headers['Cookie'],
            'dle_sort_xfsearch=$field; '
            'dle_direction_xfsearch=${ascending ? 'asc' : 'desc'}; dle_no_cache=1',
          );
        }
        dio.close(force: true);
      }
    }
  });

  test('author page two rejects missing, ambiguous and wrong next-click indicators', () async {
    const path = '/filter/author/%f1%e8%ed%ee%f5%e0%f0%e0+%f2%e8%fd/';
    const good = '<a class="sort-actv" onclick="dle_change_sort(\'title\',\'desc\');">sort</a>';
    const wrong = '<a class="sort-actv" onclick="dle_change_sort(\'title\',\'asc\');">sort</a>';
    const malformed = '<a class="sort-actv" onclick="dle_change_sort(\'title\',\'sideways\');">sort</a>';
    for (final active in ['', wrong, malformed, '$good$good']) {
      final adapter = HtmlFixtureAdapter({
        Uri.parse(path).path: '<form id="news_set_sort">$good</form>$catalogHtml',
        Uri.parse('${path}page/2/').path: '<form id="news_set_sort">$active</form>$catalogHtml',
      });
      final dio = Dio(BaseOptions(baseUrl: 'https://v30.astar.bz/'))..httpClientAdapter = adapter;
      final client = createTestAnistarClient(dio);
      const sort = AnistarCatalogSort(AnistarSortCriterion.title, ascending: true);
      await client.catalog(1, filterPath: path, sort: sort);
      await expectLater(client.catalog(2, filterPath: path, sort: sort), throwsA(isA<AnistarClientException>()));
      expect(adapter.requests, hasLength(2));
      expect(adapter.requests.last.path, '${path.substring(1)}page/2/');
      dio.close(force: true);
    }
  });

  test('HTTP pages retain ordered unique entries and source continuation', () async {
    const first = '<div class="news"><div class="title_left"><a href="/1-first.html">First</a></div></div>';
    const second = '<div class="news"><div class="title_left"><a href="/2-second.html">Second</a></div></div>';
    final dio = Dio(BaseOptions(baseUrl: 'https://v30.astar.bz/'))
      ..httpClientAdapter = HtmlFixtureAdapter({
        '/anime/': '$first<a href="/anime/page/2/">2</a>',
        '/anime/page/2/': '$first$first<a href="/anime/page/3/">3</a>',
        '/anime/page/3/': second,
      });
    addTearDown(() => dio.close(force: true));
    final repository = AnistarCatalogRepository(createTestAnistarClient(dio));
    final pages = <(List<int>, bool)>[];
    for (var number = 1; number <= 3; number++) {
      final page = (await repository.getPage(number))
          .when(failure: (failure) => fail(failure.message), success: (page) => page);
      pages.add((page.items.map((item) => item.id).toList(), page.hasNext));
    }
    expect(pages.map((page) => page.$1), [
      [1],
      [1],
      [2],
    ]);
    expect(pages.map((page) => page.$2), [true, true, false]);
  });

  test('catalog repository loads HTML without parser endpoints', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://v30.astar.bz/'));
    final adapter = HtmlFixtureAdapter({'/anime/': catalogHtml});
    dio.httpClientAdapter = adapter;
    final repository = AnistarCatalogRepository(createTestAnistarClient(dio));
    final page = (await repository.getPage(1))
        .when(failure: (failure) => fail(failure.message), success: (page) => page);
    expect(page.items.single.id, 10938);
    expect(page.hasNext, isTrue);
    expect(adapter.requests.single.uri.path, '/anime/');
  });

  test('source metadata reaches catalog domain without rewriting paths', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://v30.astar.bz/'))
      ..httpClientAdapter = HtmlFixtureAdapter({
        '/anime/': '''
<div class="news"><div class="title_left"><a href="/42-test.html">Fixture</a></div>
<ul class="head"><li><b>Серии:</b> ТВ (&gt;12 эп.)</li><li><b>Озвучка:</b> AniStar</li>
<li><b>Жанр:</b> <a href="/filter/janrs/%e4%f0%e0%ec%e0+%f2%e5%f1%f2/">Драма</a>,
<a href="https://foreign.test/filter/janrs/foreign/">Чужой</a></li></ul>
<div class="reason">Добавлена 7 серия</div><span class="date-icon">Вчера, 23:59</span></div>
''',
      });
    addTearDown(() => dio.close(force: true));
    final page = (await AnistarCatalogRepository(createTestAnistarClient(dio)).getPage(1))
        .when(failure: (failure) => fail(failure.message), success: (page) => page);
    final item = page.items.single;
    expect((item.seriesInfo, item.voiceover), ('ТВ (>12 эп.)', 'AniStar'));
    expect(item.genres, ['Драма', 'Чужой']);
    expect(item.genreFilters.map((filter) => (filter.label, filter.path)), [
      ('Драма', '/filter/janrs/%e4%f0%e0%ec%e0+%f2%e5%f1%f2/'),
    ]);
    expect((item.updateMessage, item.publicationDate), ('Добавлена 7 серия', 'Вчера, 23:59'));
  });
}
