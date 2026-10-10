import 'package:anistar/anistar.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../mocks/anistar/anistar_fixtures.dart';
import '../../mocks/networking/html_fixture_adapter.dart';

void main() {
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
      await expectLater(AnistarSource(dio).catalog(1), throwsA(isA<AnistarFailure>()));
      final headers = adapter.requests.single.headers;
      expect(headers['Accept'], 'text/html');
      expect(headers['User-Agent'], 'AniStarTV/1.0');
      expect(headers['Cache-Control'], 'no-cache');
    }
  });

  test('transport errors remain Dio errors for the repository boundary', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://v30.astar.bz/'))
      ..httpClientAdapter = HtmlFixtureAdapter({'/anime/': 'Unavailable'}, statusCode: 503);
    addTearDown(() => dio.close(force: true));
    await expectLater(AnistarSource(dio).catalog(1), throwsA(isA<DioException>()));
  });
}
