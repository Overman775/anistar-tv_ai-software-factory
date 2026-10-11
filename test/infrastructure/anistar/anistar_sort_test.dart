import 'package:anistar/anistar.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../mocks/anistar/anistar_fixtures.dart';
import '../../mocks/anistar/test_anistar_client.dart';
import '../../mocks/networking/html_fixture_adapter.dart';
import '../../mocks/storage/memory_secure_storage.dart';

String _html(DirectCatalogSort sort) =>
    '''
<form id="news_set_sort"><a class="sort-actv" onclick="dle_change_sort('${sort.field}','${sort.ascending ? 'desc' : 'asc'}'); return false;">sort</a>
<input name="dlenewssortby" value="date"><input name="dledirection" value="DESC"></form>
$catalogHtml
''';

void main() {
  for (final criterion in DirectSortCriterion.values) {
    for (final ascending in [false, true]) {
      test('GET ${criterion.name} ascending=$ascending keeps order through category and encoded pagination', () async {
        final sort = DirectCatalogSort(criterion, ascending: ascending);
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
          for (final request in adapter.requests) {
            expect(request.method, 'GET');
            expect(request.uri.query, isEmpty);
            expect(
              request.headers['Cookie'],
              sort.cookies(path).entries.map((entry) => '${entry.key}=${entry.value}').join('; '),
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
    const sort = DirectCatalogSort(DirectSortCriterion.title, ascending: true);
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
    const requested = DirectCatalogSort(DirectSortCriterion.title, ascending: true);
    for (final html in [
      catalogHtml,
      _html(const DirectCatalogSort(DirectSortCriterion.date)),
      _html(const DirectCatalogSort(DirectSortCriterion.title)),
    ]) {
      dio.httpClientAdapter = HtmlFixtureAdapter({'/comedy/': html});
      await expectLater(
        createTestAnistarClient(dio).catalog(1, filterPath: '/comedy/', sort: requested),
        throwsA(isA<AnistarFailure>()),
      );
    }
  });
}
