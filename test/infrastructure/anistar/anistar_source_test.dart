import 'package:anistar/anistar.dart';
import 'package:anistar/html.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../mocks/anistar/anistar_fixtures.dart';
import '../../mocks/anistar/test_anistar_client.dart';
import '../../mocks/networking/html_fixture_adapter.dart';
import '../../mocks/storage/memory_secure_storage.dart';

void main() {
  test('detail follows the same-origin redirect to the canonical slug', () async {
    final adapter = HtmlFixtureAdapter(
      {'/10686-canonical.html': detailHtml},
      overrides: const {
        '/10686-.html': (
          statusCode: 301,
          headers: {
            'location': ['https://v32.astar.bz/10686-canonical.html'],
          },
        ),
      },
    );
    final dio = Dio(BaseOptions(baseUrl: 'https://v32.astar.bz/'))..httpClientAdapter = adapter;
    addTearDown(() => dio.close(force: true));

    final details = await createTestAnistarClient(dio).details('10686-');

    expect((details.id, details.slug), (10686, '10686-canonical'));
    expect(adapter.requests.map((request) => request.uri.path), ['/10686-.html', '/10686-canonical.html']);
    expect(adapter.requests.every((request) => request.method == 'GET' && !request.followRedirects), isTrue);
  });

  test('intermediate detail redirect does not expire the authenticated session', () async {
    final origin = Uri.parse('https://v32.astar.bz/');
    final session = AnistarSession(origin, MemorySecureStorage());
    addTearDown(session.close);
    await session.initialize();
    final generation = session.generation;
    await session.saveCookies(origin, ['dle_user_id=42; Path=/; Secure'], generation);
    await session.authenticate('account', generation);
    final access = session.accessGeneration;
    final adapter = HtmlFixtureAdapter(
      {'/10686-.html': '<input name="login_password">', '/10686-canonical.html': detailHtml},
      overrides: const {
        '/10686-.html': (
          statusCode: 301,
          headers: {
            'location': ['/10686-canonical.html'],
          },
        ),
      },
    );
    final dio = Dio(BaseOptions(baseUrl: origin.toString()))..httpClientAdapter = adapter;
    addTearDown(() => dio.close(force: true));
    dio.interceptors.add(AnistarSessionInterceptor(session));

    final details = await createTestAnistarClient(dio, session: session).details('10686-');

    expect(details.slug, '10686-canonical');
    expect(session.account, 'account');
    expect(session.accessGeneration, access);
    expect(adapter.requests.map((request) => request.headers['Cookie']), ['dle_user_id=42', 'dle_user_id=42']);
  });

  for (final location in [
    null,
    'https://foreign.test/10686-canonical.html',
    'http://v32.astar.bz/10686-canonical.html',
    'https://user@v32.astar.bz/10686-canonical.html',
    '/10687-other.html',
    '/10686-canonical.html?token=demo',
    '/10686-canonical.html#fragment',
    '/10686-%2Fother.html',
    '/archive/../10686-canonical.html',
    '/10686-.html',
  ]) {
    test('detail denies unsafe or repeated redirect location $location', () async {
      final adapter = HtmlFixtureAdapter(
        const {},
        overrides: {
          '/10686-.html': (
            statusCode: 301,
            headers: {
              if (location != null) 'location': [location],
            },
          ),
        },
      );
      final dio = Dio(BaseOptions(baseUrl: 'https://v32.astar.bz/'))..httpClientAdapter = adapter;
      addTearDown(() => dio.close(force: true));

      await expectLater(createTestAnistarClient(dio).details('10686-'), throwsA(isA<AnistarClientException>()));
      expect(adapter.requests.map((request) => request.uri.path), ['/10686-.html']);
    });
  }

  test('detail detects a two-address redirect cycle', () async {
    final adapter = HtmlFixtureAdapter(
      const {},
      overrides: const {
        '/10686-.html': (
          statusCode: 301,
          headers: {
            'location': ['/10686-canonical.html'],
          },
        ),
        '/10686-canonical.html': (
          statusCode: 301,
          headers: {
            'location': ['/10686-.html'],
          },
        ),
      },
    );
    final dio = Dio(BaseOptions(baseUrl: 'https://v32.astar.bz/'))..httpClientAdapter = adapter;
    addTearDown(() => dio.close(force: true));

    await expectLater(createTestAnistarClient(dio).details('10686-'), throwsA(isA<AnistarClientException>()));
    expect(adapter.requests.map((request) => request.uri.path), ['/10686-.html', '/10686-canonical.html']);
  });

  test('detail stops after three redirects', () async {
    final adapter = HtmlFixtureAdapter(
      {'/10686-hop4.html': detailHtml},
      overrides: {
        for (var hop = 0; hop < 4; hop++)
          '/10686-hop$hop.html': (
            statusCode: 301,
            headers: {
              'location': ['/10686-hop${hop + 1}.html'],
            },
          ),
      },
    );
    final dio = Dio(BaseOptions(baseUrl: 'https://v32.astar.bz/'))..httpClientAdapter = adapter;
    addTearDown(() => dio.close(force: true));

    await expectLater(createTestAnistarClient(dio).details('10686-hop0'), throwsA(isA<AnistarClientException>()));
    expect(adapter.requests.map((request) => request.uri.path), [
      '/10686-hop0.html',
      '/10686-hop1.html',
      '/10686-hop2.html',
      '/10686-hop3.html',
    ]);
  });

  test('site owns its HTML headers; rejects 403 and a successful challenge response', () async {
    for (final statusCode in [200, 403]) {
      final dio = Dio(BaseOptions(baseUrl: 'https://v30.astar.bz/'));
      final adapter = HtmlFixtureAdapter(
        {'/anime/': catalogHtml},
        statusCode: statusCode,
        responseHeaders: statusCode == 200
            ? const {
                'cf-mitigated': ['challenge'],
              }
            : const {},
      );
      dio.httpClientAdapter = adapter;
      addTearDown(() => dio.close(force: true));
      await expectLater(createTestAnistarClient(dio).catalog(1), throwsA(isA<AnistarClientException>()));
      final headers = adapter.requests.single.headers;
      expect(headers['Accept'], 'text/html');
      expect(headers['User-Agent'], 'AniStarTV/1.0');
      expect(headers['Cache-Control'], 'no-cache');
    }
  });

  test('transport errors normalize at the client boundary', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://v30.astar.bz/'))
      ..httpClientAdapter = HtmlFixtureAdapter({'/anime/': 'Unavailable'}, statusCode: 503);
    addTearDown(() => dio.close(force: true));
    await expectLater(
      createTestAnistarClient(dio).catalog(1),
      throwsA(
        isA<AnistarClientException>().having((error) => error.category, 'category', AnistarClientErrorCategory.server),
      ),
    );
  });
}
