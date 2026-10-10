// Each request/assertion observes state after a distinct site mutation.
// ignore_for_file: prefer-moving-to-variable

import 'package:anistar/anistar.dart';
import 'package:app_logging/app_logging.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:networking/networking.dart';

import '../../mocks/anistar/watched_fixture_adapter.dart';

void main() {
  late WatchedFixtureAdapter adapter;
  late AnistarSource source;
  setUp(() {
    adapter = WatchedFixtureAdapter();
    final dio = DioClient.create(
      config: NetworkConfig(baseUri: Uri.parse('https://v30.astar.bz/')),
      logger: AppLogger.logger,
    )..httpClientAdapter = adapter;
    source = AnistarSource(dio);
    addTearDown(() => dio.close(force: true));
  });

  test('marks using the selected media ID and confirms fresh site history; already viewed does not write', () async {
    expect(await source.markWatched(animeId: 10938, episodeNumber: 2), {2});
    final writes = adapter.requests.where((request) => request.uri.path == '/engine/ajax/ns.php').toList();
    expect(writes, hasLength(1));
    expect(writes.single.queryParameters, {'vid': 'media-2'});
    expect(writes.single.headers['Referer'], 'https://v30.astar.bz/test/player2/videoas_p2p_new.php?id=10938');
    expect(await source.watchedEpisodes(10938), {2});
    await source.markWatched(animeId: 10938, episodeNumber: 2);
    expect(adapter.requests.where((request) => request.uri.path == '/engine/ajax/ns.php'), hasLength(1));
  });

  test('HTTP 200 without persisted viewing is a failure, missing series or media ID never writes', () async {
    adapter.persist = false;
    await expectLater(source.markWatched(animeId: 10938, episodeNumber: 1), throwsA(isA<AnistarFailure>()));
    adapter.requests.clear();
    await expectLater(source.markWatched(animeId: 10938, episodeNumber: 42), throwsA(isA<AnistarFailure>()));
    adapter.missingMediaId = true;
    // A separate malformed media ID must also fail before mutation.
    // ignore: avoid-duplicate-test-assertions
    await expectLater(source.markWatched(animeId: 10938, episodeNumber: 1), throwsA(isA<AnistarFailure>()));
    expect(adapter.requests.where((request) => request.uri.path == '/engine/ajax/ns.php'), isEmpty);
  });

  test('failed mutating GET has no automatic retries', () async {
    adapter.mutationStatus = 503;
    await expectLater(source.markWatched(animeId: 10938, episodeNumber: 1), throwsA(isA<DioException>()));
    expect(adapter.requests.where((request) => request.uri.path == '/engine/ajax/ns.php'), hasLength(1));
    expect(adapter.watched, isEmpty);
  });
}
