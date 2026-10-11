import 'package:anistar_tv/packages/features/player/data/repositories/anistar_playback_repository.dart';
import 'package:anistar_tv/packages/features/player/domain/models/playback_failure.dart';
import 'package:anistar_tv/packages/features/player/domain/models/playback_quality.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../../mocks/anistar/anistar_fixtures.dart';
import '../../../../../mocks/anistar/test_anistar_client.dart';
import '../../../../../mocks/networking/html_fixture_adapter.dart';

void main() {
  test('an out-of-range optional expiry does not discard a playable signed URL', () async {
    final source = playerHtml.replaceAll('end=1893456000', 'end=9999999999999999999999999');
    final dio = Dio(BaseOptions(baseUrl: 'https://v30.astar.bz/'))
      ..httpClientAdapter = HtmlFixtureAdapter({'/test/player2/videoas_p2p_new.php': source});
    addTearDown(() => dio.close(force: true));
    final result = await AnistarPlaybackRepository(createTestAnistarClient(dio))
        .createSession(animeId: 10938, episodeNumber: 1);
    expect(result.isSuccess, isTrue);
    expect(result.successOrNull?.expiresAt, isNull);
    expect(result.successOrNull?.manifestUri.toString(), contains('end=9999999999999999999999999'));
  });

  test('signed 720 HLS and Referer remain intact; refresh refetches player', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://v30.astar.bz/'));
    addTearDown(() => dio.close(force: true));
    final adapter = HtmlFixtureAdapter({'/test/player2/videoas_p2p_new.php': playerHtml});
    dio.httpClientAdapter = adapter;
    final repository = AnistarPlaybackRepository(createTestAnistarClient(dio));
    final session = (await repository.createSession(
      animeId: 10938,
      episodeNumber: 1,
    )).when(failure: (failure) => fail(failure.message), success: (value) => value);
    expect(session.manifestUri.toString(), signed720);
    expect(session.httpHeaders['Referer'], 'https://v30.astar.bz/test/player2/videoas_p2p_new.php?id=10938');
    expect(session.episodeNumbers, [1, 2]);
    expect(session.expiresAt, DateTime.utc(2030));
    final fallback = (await repository.createSession(
      animeId: 10938,
      episodeNumber: 2,
    )).when(failure: (failure) => fail(failure.message), success: (value) => value);
    expect(fallback.selectedQuality, PlaybackQuality.low);
    expect(adapter.requests, hasLength(2));
    expect(adapter.requests.last.headers['Cache-Control'], 'no-cache');
    final missing = await repository.createSession(animeId: 10938, episodeNumber: 9);
    expect(missing.when(failure: (failure) => failure, success: (_) => null), isA<PlaybackFailure>());
  });
}
