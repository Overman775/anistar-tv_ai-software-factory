import 'package:anistar/anistar.dart';
import 'package:anistar/parsing.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../mocks/anistar/anistar_fixtures.dart';

void main() {
  final parser = AnistarHtmlParser(Uri.parse('https://v30.astar.bz/'));

  test('desktop catalog removes advertisement and reads real pagination', () {
    final page = parser.catalog(catalogHtml, 1);
    final item = page.items.single;
    expect(item.id, 10938);
    expect(item.slug, '10938-test');
    expect(page.hasNext, isTrue);
    expect(parser.catalog(catalogHtml, 690).hasNext, isFalse);
  });

  test('catalog ratings retain decimals and zero without inventing missing scores', () {
    for (final (markup, expected) in <(String, double?)>[
      ('<span>рейтинг 7.7/10</span>', 7.7),
      ('<span>рейтинг 8,2/10</span>', 8.2),
      ('<meta itemprop="ratingValue" content="9.1">', 9.1),
      ('<span>рейтинг 0/10</span>', 0),
      ('<span>рейтинг 10/10</span>', 10),
      ('<span>12 серий</span>', null),
      ('<span>рейтинг 12/10</span>', null),
    ]) {
      final page = parser.catalog(
        '<div class="news"><div class="title_left"> '
        '<a href="/10938-test.html">Название</a></div>$markup</div>',
        1,
      );
      expect(page.items.single.rating, expected);
    }
  });

  test('mobile layout and duplicate cards retain one actual anime', () {
    const card =
        '<div class="plash"><a href="/10938-test.html"><span class="title-top">Название</span><div class="poster"><img src="/p.jpg"></div></a></div>';
    final page = parser.catalog('$card$card', 1);
    final item = page.items.single;
    expect(item.title, 'Название');
    expect(item.posterUri, Uri.parse('https://v30.astar.bz/p.jpg'));
  });

  test('card metadata and entities become readable domain data', () {
    final detail = parser.details(detailHtml, '10938-test');
    expect(detail.title, 'Тестовое аниме & друзья');
    expect(detail.genres, ['Приключения', 'Комедия']);
    expect(detail.year, '2026');
    expect(detail.description, 'Описание аниме.');
    expect(detail.isOngoing, isTrue);
  });

  test('JSON5 preserves signed HLS .mp4, episode association and preview', () {
    final episodes = parser.episodes(playerHtml);
    expect(episodes.map((episode) => episode.number), [1, 2]);
    expect(episodes.first.sources['720']?.toString(), signed720);
    expect(episodes.last.sources.keys, ['360']);
    expect(episodes.first.previewUri, Uri.parse('https://v30.astar.bz/preview.jpg'));
  });

  test('viewing is read from its episode object and only boolean true is watched', () {
    final episodes = parser.episodes(
      "var playlst=[{title:'Серия 3',viewing:'true'}, {title:'Серия 2',viewing:true}, {title:'Серия 1',viewing:false}];",
    );
    expect(episodes.map((episode) => episode.isWatched), [false, true, false]);
  });

  test('challenge and changed markup return actionable failures', () {
    final failure = throwsA(isA<AnistarFailure>());
    expect(() => parser.catalog('<h1>Проверяем ваш браузер</h1>', 1), failure);
    expect(() => parser.episodes('var playlst = malformed;'), failure);
    expect(() => parser.details('<title>Not an anime</title>', '10938-test'), failure);
  });

  test('balanced literal handles comments, escaped strings and closing brackets', () {
    final episodes = parser.episodes(
      r'''const playlst=[/* ] */ {title:'Серия 1', image:'x]y',files:[{title:'360',file:'https://cdn.test/a.m3u8'}], note:'don\'t ]'},]; throwError();''',
    );
    expect(episodes.single.sources['360'], Uri.parse('https://cdn.test/a.m3u8'));
    expect(() => parser.episodes('var playlst=[{title:"Серия 1"}'), throwsA(isA<AnistarFailure>()));
  });

  test('CP1251 is decoded according to response charset', () {
    expect(HtmlDecoder.decode([0xcf, 0xf0, 0xe8, 0xe2, 0xe5, 0xf2], 'text/html; charset=Windows-1251'), 'Привет');
    expect(HtmlDecoder.decode([0xd0, 0x90], 'text/html; charset=UTF-8'), 'А');
  });
}
