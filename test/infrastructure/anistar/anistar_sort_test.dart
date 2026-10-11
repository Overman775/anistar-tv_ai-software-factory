import 'package:anistar/anistar.dart';
import 'package:anistar/html.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../mocks/anistar/anistar_fixtures.dart';
import '../../mocks/anistar/test_anistar_client.dart';
import '../../mocks/networking/html_fixture_adapter.dart';
import '../../mocks/storage/memory_secure_storage.dart';

String _field(AnistarCatalogSort sort) => switch (sort.criterion) {
  AnistarSortCriterion.date => 'date',
  AnistarSortCriterion.rating => 'rating',
  AnistarSortCriterion.views => 'news_read',
  AnistarSortCriterion.comments => 'comm_num',
  AnistarSortCriterion.title => 'title',
};

String _html(AnistarCatalogSort sort) =>
    '''
<form id="news_set_sort"><a class="sort-actv" onclick="dle_change_sort('${_field(sort)}','${sort.ascending ? 'desc' : 'asc'}'); return false;">sort</a>
<input name="dlenewssortby" value="date"><input name="dledirection" value="DESC"></form>
$catalogHtml
''';

void main() {
  for (final criterion in AnistarSortCriterion.values) {
    for (final ascending in [false, true]) {
      test('GET ${criterion.name} ascending=$ascending keeps order through category and encoded pagination', () async {
        final sort = AnistarCatalogSort(criterion, ascending: ascending);
        final dio = Dio(BaseOptions(baseUrl: 'https://v30.astar.bz/'));
        addTearDown(() => dio.close(force: true));
        for (final path in ['/comedy/', '/filter/janrs/%EA%EE%EC%E5%E4%E8%FF/']) {
          final html = _html(sort);
          final adapter = HtmlFixtureAdapter({path: html, '${path}page/2/': html});
          dio.httpClientAdapter = adapter;
          final source = createTestAnistarClient(dio);
          await source.catalog(1, filterPath: path, sort: sort);
          await source.catalog(2, filterPath: path, sort: sort);
          expect(adapter.requests.map((request) => request.uri.path), [path, '${path}page/2/']);
          final suffix = path.startsWith('/filter/') ? 'xfsearch' : 'cat';
          for (final request in adapter.requests) {
            expect(request.method, 'GET');
            expect(request.uri.query, isEmpty);
            expect(
              request.headers['Cookie'],
              'dle_sort_$suffix=${_field(sort)}; '
              'dle_direction_$suffix=${ascending ? 'asc' : 'desc'}; dle_no_cache=1',
            );
          }
        }
      });
    }
  }

  test('scoped cookies preserve auth, replace old ordering, and never change the shared jar', () async {
    final origin = Uri.parse('https://v30.astar.bz/');
    final session = AnistarSession(origin, MemorySecureStorage());
    addTearDown(session.close);
    await session.saveCookies(origin, [
      'dle_user_id=42; Path=/',
      'dle_sort_cat=rating; Path=/',
      'dle_direction_cat=desc; Path=/',
    ], 0);
    // Read before and after the request to detect mutation.
    // ignore: prefer-moving-to-variable
    final before = await session.cookieHeader(origin);
    const sort = AnistarCatalogSort(AnistarSortCriterion.title, ascending: true);
    final dio = Dio(BaseOptions(baseUrl: origin.toString()));
    addTearDown(() => dio.close(force: true));
    dio.interceptors.add(AnistarSessionInterceptor(session));
    final adapter = HtmlFixtureAdapter(
      {'/comedy/': _html(sort), '/anime/': catalogHtml},
      responseHeaders: {
        'set-cookie': ['dle_sort_cat=title; Path=/', 'dle_direction_cat=asc; Path=/', 'dle_no_cache=1; Path=/'],
      },
    );
    dio.httpClientAdapter = adapter;
    final client = createTestAnistarClient(dio, session: session);
    await client.catalog(1, filterPath: '/comedy/', sort: sort);
    final sent = adapter.requests.single.headers['Cookie'] as String;
    expect(sent, contains('dle_user_id=42'));
    expect(sent, contains('dle_sort_cat=title'));
    expect(sent, isNot(contains('dle_sort_cat=rating')));
    // ignore: prefer-moving-to-variable
    expect(await session.cookieHeader(origin), before);
    await client.catalog(1);
    expect(adapter.requests.last.headers['Cookie'], before);
  });

  test('unchanged indicator, changed direction and absent sort form are errors, never fallback results', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://v30.astar.bz/'));
    addTearDown(() => dio.close(force: true));
    const requested = AnistarCatalogSort(AnistarSortCriterion.title, ascending: true);
    for (final html in [
      catalogHtml,
      _html(const AnistarCatalogSort(AnistarSortCriterion.date)),
      _html(const AnistarCatalogSort(AnistarSortCriterion.title)),
    ]) {
      dio.httpClientAdapter = HtmlFixtureAdapter({'/comedy/': html});
      await expectLater(
        createTestAnistarClient(dio).catalog(1, filterPath: '/comedy/', sort: requested),
        throwsA(isA<AnistarClientException>()),
      );
    }
  });
}
