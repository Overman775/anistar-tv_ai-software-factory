import 'dart:async';

import 'package:anistar/anistar.dart';
import 'package:anistar/parsing.dart';
import 'package:anistar_tv/packages/features/anime/data/repositories/anistar_anime_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:networking/networking.dart';

import '../../../../../mocks/anistar/anistar_fixtures.dart';
import '../../../../../mocks/anistar/fake_anistar_client.dart';
import '../../../../../mocks/anistar/test_anistar_client.dart';
import '../../../../../mocks/networking/html_fixture_adapter.dart';

void main() {
  for (final detailsFirst in [true, false]) {
    test('aggregate waits for both requests when ${detailsFirst ? 'details' : 'episodes'} arrive first', () async {
      final details = Completer<AnistarAnimeDetailsDto>();
      final episodes = Completer<List<AnistarEpisodeDto>>();
      final client = FakeAnistarClient()
        ..loadDetails = ((_) => details.future)
        ..loadEpisodes = ((_) => episodes.future);
      final repository = AnistarAnimeRepository(client);
      var finished = false;
      final result = repository.getAnime(id: 1, slug: '1-anime').whenComplete(() => finished = true);
      expect(client.calls, ['details', 'episodes']);

      final playlist = [AnistarEpisodeDto(number: 1, title: 'Серия 1', sources: const [])];
      if (detailsFirst) {
        details.complete(client.detailResult);
      } else {
        episodes.complete(playlist);
      }
      await pumpEventQueue();
      expect(finished, isFalse);
      if (detailsFirst) {
        episodes.complete(playlist);
      } else {
        details.complete(client.detailResult);
      }
      final data = (await result).when(failure: (failure) => fail(failure.message), success: (value) => value);
      expect(data.details.id, 1);
      expect(data.episodes.map((episode) => episode.number), [1]);
    });
  }

  const detailPath = '/10938-test.html';
  const playerPath = '/test/player2/videoas_p2p_new.php';
  for (final (name, initialResponses) in [
    ('details fails', {playerPath: playerHtml}),
    ('episodes fails', {detailPath: detailHtml}),
    ('playlist is unusable', {detailPath: detailHtml, playerPath: "var playlst = [{title: 'Серия 0', files: []}];"}),
  ]) {
    test('$name gives a common failure and the next load requests both parts again', () async {
      final adapter = HtmlFixtureAdapter(initialResponses);
      final dio = Dio(BaseOptions(baseUrl: 'https://fixture.test/'))..httpClientAdapter = adapter;
      addTearDown(() => dio.close(force: true));
      final repository = AnistarAnimeRepository(createTestAnistarClient(dio));

      final failure = await repository.getAnime(id: 10938, slug: '10938-test');
      expect(failure.when(failure: (value) => value, success: (_) => null), isA<RequestFailure>());
      expect(adapter.requests.map((request) => request.uri.path), unorderedEquals([detailPath, playerPath]));
      adapter.responses.addAll({detailPath: detailHtml, playerPath: playerHtml});

      final retry = await repository.getAnime(id: 10938, slug: '10938-test');
      final data = retry.when(failure: (failure) => fail(failure.message), success: (value) => value);
      expect(data.episodes.map((episode) => episode.number), [1, 2]);
      expect(adapter.requests.skip(2).map((request) => request.uri.path), unorderedEquals([detailPath, playerPath]));
    });
  }

  test('same-named director and author retain both paths in source order', () async {
    const director = '/filter/director/%f1%e8%ed%ee%f5%e0%f0%e0+%f2%e8%fd/';
    const author = '/filter/author/%f1%e8%ed%ee%f5%e0%f0%e0+%f2%e8%fd/';
    const rows = {
      director: '<li><b>Режиссёр:</b> <a href="$director">Синохара Тиэ</a></li>',
      author: '<li><b>Автор:</b> <a href="$author">Синохара Тиэ</a></li>',
    };
    for (final order in [
      <String>[director, author],
      <String>[author, director],
    ]) {
      final html = detailHtml.replaceFirst('</ul>', '${order.map((path) => rows[path]).join()}</ul>');
      final expected = order.map((path) => ('Синохара Тиэ', path)).toList();
      final parsed = AnistarHtmlParser(Uri.parse('https://v30.astar.bz/')).details(html, '10938-test');
      expect(parsed.filters.map((filter) => (filter.label, filter.path)), expected);
      final dio = Dio(BaseOptions(baseUrl: 'https://v30.astar.bz/'))
        ..httpClientAdapter = HtmlFixtureAdapter({
          '/10938-test.html': html,
          '/test/player2/videoas_p2p_new.php': playerHtml,
        });
      addTearDown(() => dio.close(force: true));
      final result = await AnistarAnimeRepository(createTestAnistarClient(dio)).getAnime(id: 10938, slug: '10938-test');
      final data = result.when(failure: (failure) => fail(failure.message), success: (value) => value);
      expect(data.details.filters.map((filter) => (filter.label, filter.path)), expected);
    }
  });

  test('detail and sorted episodes are fetched directly from HTML', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://v30.astar.bz/'))
      ..httpClientAdapter = HtmlFixtureAdapter({
        '/10938-test.html': detailHtml,
        '/test/player2/videoas_p2p_new.php': playerHtml,
      });
    addTearDown(() => dio.close(force: true));
    final repository = AnistarAnimeRepository(createTestAnistarClient(dio), null, () => true);
    final data = (await repository.getAnime(
      id: 10938,
      slug: '10938-test',
    )).when(failure: (failure) => fail(failure.message), success: (value) => value);
    expect(data.details.genres, ['Приключения', 'Комедия']);
    expect(data.episodes.map((episode) => episode.number), [1, 2]);
    final missing = await repository.getAnime(id: 10938, slug: '10938-missing');
    expect(missing.when(failure: (failure) => failure, success: (_) => null), isA<RequestFailure>());
  });

  test('details retain author, ordered part labels and playlist availability', () async {
    final html = detailHtml.replaceFirst('</ul>', '''
<li><b>Автор:</b> <a href="/filter/author/%f1%e8%ed%ee%f5%e0%f0%e0+%f2%e8%fd/">Синохара Тиэ</a></li></ul>
<div class="news_text"><div class="title_spoiler">Серия состоит из:</div><div class="text_spoiler">
<a href="/10938-test.html">Первая часть полностью</a>
<a href="https://foreign.test/42-other.html">Внешняя часть</a>
<a href="/10686-.html">Последняя часть полностью</a></div></div>
<div class="reason">Добавлена 7 серия</div><span class="date-icon">Сегодня, 23:59</span>''');
    final dio = Dio(BaseOptions(baseUrl: 'https://v30.astar.bz/'))
      ..httpClientAdapter = HtmlFixtureAdapter({
        '/10938-test.html': html,
        '/test/player2/videoas_p2p_new.php': playerHtml,
      });
    addTearDown(() => dio.close(force: true));
    final result = await AnistarAnimeRepository(createTestAnistarClient(dio)).getAnime(id: 10938, slug: '10938-test');
    final data = result.when(failure: (failure) => fail(failure.message), success: (value) => value);
    expect(data.details.author, 'Синохара Тиэ');
    expect(data.details.filters.map((filter) => (filter.label, filter.path)), [
      ('Синохара Тиэ', '/filter/author/%f1%e8%ed%ee%f5%e0%f0%e0+%f2%e8%fd/'),
    ]);
    expect(data.details.parts.map((part) => (part.label, part.id, part.slug)), [
      ('Первая часть полностью', 10938, '10938-test'),
      ('Внешняя часть', null, null),
      ('Последняя часть полностью', 10686, '10686-'),
    ]);
    expect((data.details.updateMessage, data.details.publicationDate), ('Добавлена 7 серия', 'Сегодня, 23:59'));
    expect(data.details.seriesInfo, '14 эп., 25 мин.');
    expect(data.episodes.map((episode) => episode.number), [1, 2]);
  });
}
