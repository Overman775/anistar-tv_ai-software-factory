import 'package:anistar/anistar.dart';
import 'package:anistar/src/anistar_favorites_html.dart';
import 'package:anistar/src/anistar_html_parser.dart';
import 'package:app_logging/app_logging.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:networking/networking.dart';

import '../../mocks/anistar/anistar_fixtures.dart';
import '../../mocks/anistar/favorites_fixture_adapter.dart';

void main() {
  const id = 10938;
  const slug = '10938-test';
  final origin = Uri.parse('https://v30.astar.bz/');

  test('reads only the requested ID, treats ambiguity and missing controls as unknown', () {
    const other = '<img onclick="doFavorites(42,\'minus\')">';
    const added = '<img onclick="doFavorites(\'10938\',\'minus\');return false">';
    const removed = '<img onclick="doFavorites(10938,\'plus\')">';
    expect(AnistarFavoritesHtml.fragmentStatus('$other$added', id), isTrue);
    expect(AnistarFavoritesHtml.fragmentStatus(removed, id), isFalse);
    expect(AnistarFavoritesHtml.fragmentStatus('$added$removed', id), isNull);
    expect(AnistarFavoritesHtml.fragmentStatus(other, id), isNull);
    expect(
      AnistarFavoritesHtml.fragmentStatus('<a href="/?do=favorites&amp;id=10938&amp;doaction=del">x</a>', id),
      isTrue,
    );
  });

  test('extracts the literal skin without running scripts and rejects unsafe values', () {
    expect(
      AnistarFavoritesHtml.skin(r'''<script>var dle_skin='new\x33\x36';throw Error('never run');</script>'''),
      'new36',
    );
    expect(() => AnistarFavoritesHtml.skin('<script>var dle_skin="../bad";</script>'), throwsA(isA<AnistarFailure>()));
  });

  test('maps card and detail flags independently and detects favorite pagination', () {
    final parser = AnistarHtmlParser(origin);
    final marked = catalogHtml.replaceFirst(
      'Тестовое аниме</a></div>',
      'Тестовое аниме</a></div><img onclick="doFavorites(10938,\'minus\')">',
    );
    expect(parser.catalog(marked, 1).items.single.isFavorite, isTrue);
    expect(parser.details('$detailHtml<img onclick="doFavorites(10938,\'plus\')">', slug).isFavorite, isFalse);
    final next = '$marked<a href="/index.php?do=favorites&amp;cstart=2">2</a>';
    expect(parser.catalog(next, 1, favorites: true).hasNext, isTrue);
    expect(parser.catalog(next, 2, favorites: true).hasNext, isFalse);
    expect(
      parser.catalog('$marked<a href="https://other.test/favorites/page/8/">8</a>', 1, favorites: true).hasNext,
      isFalse,
    );
  });

  test('empty favorites require the explicit site marker, not merely missing cards', () {
    final parser = AnistarHtmlParser(origin);
    const empty = '<div id="dle-content">Вы ещё ничего не добавляли в свои закладки.</div>';
    expect(parser.catalog(empty, 1, favorites: true).items, isEmpty);
    final failure = throwsA(isA<AnistarFailure>());
    expect(() => parser.catalog(empty, 1), failure);
    expect(() => parser.catalog('<h1>Ошибка</h1>', 1, favorites: true), failure);
  });

  test('authenticated empty favorites accepts the complete site shell and excludes sidebar cards', () {
    final parser = AnistarHtmlParser(origin);
    const shell =
        '<title>Мои закладки &raquo; AniStar</title> '
        '<link rel="canonical" href="https://v30.astar.bz/index.php?do=favorites&amp;cstart=1"> '
        '<a href="/index.php?action=logout">Выход</a><div id="dle-content"></div>';
    expect(parser.catalog('$shell$catalogHtml', 1, favorites: true).items, isEmpty);
    final failure = throwsA(isA<AnistarFailure>());
    expect(() => parser.catalog(shell.replaceFirst('action=logout', 'action=login'), 1, favorites: true), failure);
    expect(() => parser.catalog(shell.replaceFirst('do=favorites', 'do=other'), 1, favorites: true), failure);
    expect(() => parser.catalog(shell.replaceFirst('Мои закладки', 'Ошибка'), 1, favorites: true), failure);
    expect(() => parser.catalog(shell.replaceFirst('v30.astar.bz', 'other.test'), 1, favorites: true), failure);
    expect(
      () => parser.catalog(shell.replaceFirst('</div>', '<p>Ошибка сервера</p></div>'), 1, favorites: true),
      failure,
    );
  });

  late FavoritesFixtureAdapter adapter;
  late AnistarSource source;
  setUp(() {
    adapter = FavoritesFixtureAdapter();
    final dio = DioClient.create(
      config: NetworkConfig(baseUri: origin),
      logger: AppLogger.logger,
    )..httpClientAdapter = adapter;
    source = AnistarSource(dio);
    addTearDown(() => dio.close(force: true));
  });

  test('reads the website list through canonical DLE pagination', () async {
    expect((await source.favorites(2)).items, isEmpty);
    expect(adapter.requests.single.uri.queryParameters, {'do': 'favorites', 'cstart': '2'});
  });

  test('add and remove require AJAX acknowledgment and a fresh detail confirmation', () async {
    expect(await source.setFavorite(animeId: id, slug: slug, favorite: true), isTrue);
    expect(await source.setFavorite(animeId: id, slug: slug, favorite: false), isFalse);
    final writes = adapter.requests.where((request) => request.uri.path.contains('/ajax/')).toList();
    expect(writes.map((request) => request.queryParameters['action']), ['plus', 'minus']);
    final write = writes.first;
    expect(write.queryParameters, {'fav_id': id, 'action': 'plus', 'skin': 'new36', 'alert': 0});
    expect(write.headers['Referer'], '$origin$slug.html');
    expect(write.headers['X-Requested-With'], 'XMLHttpRequest');
    expect(adapter.requests.where((request) => request.uri.path.endsWith('.html')), hasLength(4));
  });

  test('explicit desired state is idempotent and never toggles blindly', () async {
    adapter.favorite = true;
    await source.setFavorite(animeId: id, slug: slug, favorite: true);
    expect(adapter.requests, hasLength(1));
    expect(adapter.favorite, isTrue);
  });

  test('HTTP 200 error, wrong response ID and unpersisted changes cannot count as success', () async {
    for (final mode in ['reject', 'wrongId', 'persist']) {
      adapter
        ..favorite = false
        ..reject = mode == 'reject'
        ..wrongId = mode == 'wrongId'
        ..persist = mode != 'persist';
      await expectLater(source.setFavorite(animeId: id, slug: slug, favorite: true), throwsA(isA<AnistarFailure>()));
    }
  });

  test('mutating GET is not automatically retried on 503; mismatched ID never writes', () async {
    adapter.mutationStatus = 503;
    await expectLater(source.setFavorite(animeId: id, slug: slug, favorite: true), throwsA(isA<DioException>()));
    expect(adapter.requests.where((request) => request.uri.path.contains('/ajax/')), hasLength(1));
    final requestCount = adapter.requests.length;
    await expectLater(source.setFavorite(animeId: 42, slug: slug, favorite: true), throwsA(isA<AnistarFailure>()));
    expect(adapter.requests, hasLength(requestCount));
  });
}
