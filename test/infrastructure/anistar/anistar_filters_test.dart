import 'package:anistar/anistar.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../mocks/anistar/anistar_fixtures.dart';
import '../../mocks/anistar/test_anistar_client.dart';
import '../../mocks/networking/html_fixture_adapter.dart';

void main() {
  late Dio dio;
  late HtmlFixtureAdapter adapter;
  setUp(() {
    dio = Dio(BaseOptions(baseUrl: 'https://v30.astar.bz/'));
  });
  tearDown(() => dio.close(force: true));

  test('genres come from the site genre menu, with duplicate and unsafe links removed', () async {
    adapter = HtmlFixtureAdapter({
      '/anime/': '''
        <div class="block-janrs">
          <a href="/comedy/"><span>Комедия</span></a>
          <a href="https://v30.astar.bz/comedy/">Комедия</a>
          <a href="/senen/">Сёнен</a>
          <a href="https://other.test/drama/">Драма</a>
          <a href="javascript:alert(1)">Bad</a>
          <a href="/index.php?do=logout">Bad</a>
        </div><a href="/news/">Новости</a>
      ''',
    });
    dio.httpClientAdapter = adapter;
    final genres = await createTestAnistarClient(dio).genres();
    expect(genres.map((item) => item.label), ['Комедия', 'Сёнен']);
    expect(genres.map((item) => item.path), ['/comedy/', '/senen/']);
  });

  test('detail preserves category and encoded genre links without inventing links from text', () async {
    adapter = HtmlFixtureAdapter({
      '/10938-test.html': detailHtml.replaceFirst('<p class="tags">Категория: Новинки(онгоинги)</p>', '''
        <p class="tags">
          <a href="/new/">Новинки(онгоинги)</a><a href="/anime/">Аниме</a>
          <a href="/anime/comedy/">Комедия</a>
          <a href="/filter/janrs/%F8%EA%EE%EB%E0/">Школа</a>
          <a href="https://other.test/anime/drama/">Драма</a>
          <a href="/filter/year/2026/">2026</a>
        </p>'''),
    });
    dio.httpClientAdapter = adapter;
    final anime = await createTestAnistarClient(dio).details('10938-test');
    expect(anime.filters.map((item) => item.path), [
      '/new/',
      '/anime/',
      '/anime/comedy/',
      '/filter/janrs/%F8%EA%EE%EB%E0/',
      '/filter/year/2026/',
    ]);
    expect(anime.genres, ['Приключения', 'Комедия']);
  });

  for (final path in [
    '/anime/comedy/',
    '/comedy/',
    '/new/',
    '/filter/janrs/%EA%EE%EC%E5%E4%E8%FF/',
    '/filter/year/2023/',
    '/filter/director/%C8%F1%E8%F5%E8%F0%E0+%D1%E8%ED%E4%E7%E8/',
  ]) {
    test('filtered pagination keeps the original path $path and recognizes site navigation', () async {
      final navigationPath = path == '/comedy/' ? '/anime/comedy/' : path;
      final html = catalogHtml.replaceAll('/anime/page/', '${navigationPath}page/');
      adapter = HtmlFixtureAdapter({path: html, '${path}page/2/': html});
      dio.httpClientAdapter = adapter;
      final source = createTestAnistarClient(dio);
      final first = await source.catalog(1, filterPath: path);
      final second = await source.catalog(2, filterPath: path);
      expect(first.hasNext, isTrue);
      expect(second.page, 2);
      expect(adapter.requests.map((request) => request.uri.path), [path, '${path}page/2/']);
    });
  }

  test('invalid paths are rejected before HTTP', () async {
    adapter = HtmlFixtureAdapter({});
    dio.httpClientAdapter = adapter;
    for (final path in [
      'https://other.test/anime/',
      '//other.test/',
      '/anime/../logout/',
      '/anime/?do=logout',
      '/filter/year/%2F/',
      '/filter/director/%25EF/',
      '/filter/janrs/%2F/',
      '/filter/janrs/%2E%2E/',
    ]) {
      await expectLater(
        createTestAnistarClient(dio).catalog(1, filterPath: path),
        throwsA(isA<AnistarClientException>()),
      );
    }
    expect(adapter.requests, isEmpty);
  });

  test('missing genre markup is an error instead of an empty successful list', () async {
    dio.httpClientAdapter = HtmlFixtureAdapter({'/anime/': '<html>Changed site</html>'});
    await expectLater(createTestAnistarClient(dio).genres(), throwsA(isA<AnistarClientException>()));
  });
}
