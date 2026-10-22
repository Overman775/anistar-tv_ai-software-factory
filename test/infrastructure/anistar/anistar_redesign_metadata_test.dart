import 'package:anistar/parsing.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../mocks/anistar/anistar_fixtures.dart';
import '../../mocks/anistar/test_anistar_client.dart';
import '../../mocks/networking/html_fixture_adapter.dart';

void main() {
  final origin = Uri.parse('https://v31.astar.bz/');
  final parser = AnistarHtmlParser(origin);

  test('summary keeps only actual metadata, raw publication text and immutable genres', () {
    final page = parser.catalog('''
      <div class="news"><div class="title_left"><a href="/42-fixture.html">Fixture</a></div>
      <meta itemprop="ratingValue" content="0"><ul class="head">
      <li><b>Год выпуска:</b> 2023</li><li><b>Жанр:</b> Драма, Комедия</li></ul>
      <div class="news_text"><div class="descripts">Описание <b>тайтла</b><script>unsafe()</script></div></div>
      <div class="reason">Добавлена 4 серия</div><span class="date-icon">Вчера, 23:59</span></div>
      <div class="news"><div class="title_left"><a href="/43-other.html">Other</a></div></div>
      ''', 1);
    final rich = page.items.first;
    expect((rich.rating, rich.year, rich.description), (0, '2023', 'Описание тайтла'));
    expect(rich.genres, ['Драма', 'Комедия']);
    expect(rich.updateMessage, 'Добавлена 4 серия');
    expect(rich.publicationDate, 'Вчера, 23:59');
    expect(() => rich.genres.add('Injected'), throwsUnsupportedError);
    final absent = page.items.last;
    expect([
      absent.rating,
      absent.year,
      absent.description,
      absent.updateMessage,
      absent.publicationDate,
    ], everyElement(isNull));
    expect(absent.genres, isEmpty);
  });

  for (final (raw, expected) in [('0', 0.0), ('9.2', 9.2), ('8,7', 8.7), ('10', 10.0)]) {
    test('detail owned header rating $raw wins over unrelated values', () {
      final data = parser.details(
        _ownedRatingDetail(raw, description: 'Сюжет оценивают на 8/10.', unrelated: _foreignRating),
        '10938-test',
      );
      expect(data.rating, expected);
      expect(data.title, 'Тестовое аниме & друзья');
      expect(data.year, '2026');
    });
  }

  for (final rating in ['-1', '10.1', 'NaN', 'Infinity', 'unknown', '']) {
    test('invalid owned detail rating $rating cannot borrow a body value', () {
      final data = parser.details(
        _ownedRatingDetail(
          rating,
          description: 'Сюжет оценивают на 8/10.',
          unrelated: '$_foreignRating<div class="comments">Комментарий: 6/10</div>',
        ),
        '10938-test',
      );
      expect(data.rating, isNull);
      expect(data.description, 'Сюжет оценивают на 8/10.');
    });
  }

  for (final (source, description, unrelated) in [
    ('description', 'Описание с оценкой персонажа 8/10.', ''),
    ('comment', 'Описание без рейтинга.', '<div class="comments">Комментарий: 8/10</div>'),
    ('foreign AggregateRating', 'Описание без рейтинга.', _foreignRating),
  ]) {
    test('missing owned detail rating ignores $source', () {
      final data = parser.details(
        _ownedRatingDetail(null, description: description, unrelated: unrelated),
        '10938-test',
      );
      expect(data.rating, isNull);
      expect(data.description, description);
    });
  }

  test('catalog rating lookup stays inside each card and retains zero and comma values', () {
    final page = parser.catalog('''
$_foreignRating
      <div class="news"><div class="title_left"><a href="/42-zero.html">Zero</a></div>
      <meta itemprop="ratingValue" content="0"></div>
      <div class="news"><div class="title_left"><a href="/43-normal.html">Normal</a></div>
      <meta itemprop="ratingValue" content="9.2"></div>
      <div class="news"><div class="title_left"><a href="/44-comma.html">Comma</a></div>
      <span itemprop="ratingValue">8,7</span></div>
      <div class="news"><div class="title_left"><a href="/45-absent.html">Absent</a></div></div>
      <div class="news"><div class="title_left"><a href="/46-invalid.html">Invalid</a></div>
      <meta itemprop="ratingValue" content="10.1"></div>
      <footer>Посторонняя оценка: 8/10</footer>
      ''', 1);
    expect(page.items.map((item) => (item.id, item.rating)), [(42, 0.0), (43, 9.2), (44, 8.7), (45, null), (46, null)]);
  });

  test('hidden ordered parts preserve labels and unsafe identities never become navigation', () {
    final data = parser.details('''
$detailHtml
      <div class="news_text"><div class="title_spoiler">Серия состоит из:</div>
      <div class="text_spoiler" style="display:none">
        <a href="/10938-test.html">Первый сезон целиком</a>
        <a href="/10686-.html">Второй сезон с полной подписью</a>
        <a href="https://foreign.test/42-other.html">Чужой сайт</a>
        <a href="https://user@v31.astar.bz/42-other.html">User info</a>
        <a href="/42-other.html?token=demo">Query</a>
        <a href="/42-%252fother.html">Encoded separator</a>
      </div><div class="title_spoiler">Не порядок просмотра</div>
      <div class="text_spoiler"><a href="/99-ignore.html">Не часть</a></div></div>
      ''', '10938-test');
    expect(data.parts.map((part) => part.label), [
      'Первый сезон целиком',
      'Второй сезон с полной подписью',
      'Чужой сайт',
      'User info',
      'Query',
      'Encoded separator',
    ]);
    expect(data.parts.take(2).map((part) => (part.id, part.slug)), [(10938, '10938-test'), (10686, '10686-')]);
    final unsupported = data.parts.skip(2);
    final absentValues = everyElement(isNull);
    expect(unsupported.map((part) => part.id), absentValues);
    expect(unsupported.map((part) => part.slug), absentValues);
    expect(data.parts.clear, throwsUnsupportedError);
  });

  test('detail extracts original filter hrefs and keeps unlinked director as text', () {
    final data = parser.details(
      detailHtml.replaceFirst('</ul>', '''
      <li><b>Режиссёр:</b> Полное имя режиссёра</li>
      <li><b>Год выпуска:</b><a href="/filter/year/2023/">2023</a></li>
      <li><b>Режиссёр:</b><a href="/filter/director/%C8%F1%E8%F5%E8%F0%E0+%D1%E8%ED%E4%E7%E8/">Ссылка</a></li></ul>
      '''),
      '10938-test',
    );
    expect(data.director, 'Полное имя режиссёра');
    expect(data.filters.map((filter) => filter.path), [
      '/filter/year/2023/',
      '/filter/director/%C8%F1%E8%F5%E8%F0%E0+%D1%E8%ED%E4%E7%E8/',
    ]);
  });

  test('genre images use actual nullable image URI', () {
    final filters = parser.genres('''
<div class="block-janrs">
      <a href="/comedy/"><img src="/genre.jpg">Комедия</a><a href="/drama/">Драма</a></div>''');
    expect(filters.map((filter) => filter.imageUri), [origin.resolve('/genre.jpg'), null]);
  });

  test('detail description excludes nested update/spoilers/scripts without losing prose', () {
    final source = detailHtml.replaceFirst('Описание <b>аниме</b>.', '''
Описание <b>аниме</b>.
      <div class="title_spoiler">Серия состоит из:</div><div class="text_spoiler">Hidden parts</div>
      <div class="reason">Updated</div><script>unsafe()</script><style>.hidden{}</style>''');
    final data = parser.details(source, '10938-test');
    expect(data.description?.trim(), 'Описание аниме.');
    expect(data.updateMessage, 'Updated');
  });

  test('empty slug suffix of supported part can load through public client', () async {
    final dio = Dio(BaseOptions(baseUrl: origin.toString()))
      ..httpClientAdapter = HtmlFixtureAdapter({'/10686-.html': detailHtml});
    addTearDown(() => dio.close(force: true));
    final data = await createTestAnistarClient(dio).details('10686-');
    expect((data.id, data.slug), (10686, '10686-'));
  });
}

const _foreignRating = '''
<aside itemscope itemtype="http://schema.org/AggregateRating">
  <span itemprop="ratingValue">7.7</span><span itemprop="itemReviewed">Другой объект</span>
</aside>
''';

String _ownedRatingDetail(String? rating, {required String description, required String unrelated}) {
  const title = '<h1 itemprop="name">Тестовое аниме &amp; друзья</h1>';
  final metadata = detailHtml.replaceFirst(title, '').replaceFirst('Описание <b>аниме</b>.', description);
  final ownedRating = rating == null
      ? ''
      : '''
<div class="rating"><div class="rat_col_new" itemscope itemtype="http://schema.org/AggregateRating">
  <span itemprop="ratingValue">$rating</span>
</div></div>
''';

  return '''
$unrelated
<div class="news">
  <div class="news_header"><div class="title_left">$title</div><div class="title_right">$ownedRating</div></div>
  $metadata
</div>
''';
}
