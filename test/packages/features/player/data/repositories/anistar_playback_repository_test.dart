import 'package:anistar_tv/packages/features/player/data/repositories/anistar_playback_repository.dart';
import 'package:anistar_tv/packages/features/player/domain/models/playback_quality.dart';
import 'package:api/api.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';

void main() {
  test('resolves a fresh manifest and exposes backend quality fallback', () async {
    final dio = Dio(BaseOptions(baseUrl: 'http://parser.test'));
    final adapter = DioAdapter(dio: dio);
    adapter.onGet(
      '/api/video/10921/episodes/1/playback',
      (server) => server.reply(200, {
        'anime_id': 10921,
        'episode_number': 1,
        'requested_quality': '720',
        'selected_quality': '360',
        'available_qualities': ['360'],
        'manifest_path': '/api/video/10921/episodes/1/manifest.m3u8?quality=720',
        'segment_token_ttl_seconds': 300,
      }),
      queryParameters: {'quality': '720'},
    );
    final repository = AnistarPlaybackRepository(VideoClient(dio), Uri.parse('http://parser.test/base/'));

    final session = (await repository.createSession(
      animeId: 10921,
      episodeNumber: 1,
    )).fold(onLeft: (failure) => fail(failure.message), onRight: (value) => value);

    expect(session.requestedQuality, PlaybackQuality.high);
    expect(session.selectedQuality, PlaybackQuality.low);
    expect(session.manifestUri.toString(), 'http://parser.test/api/video/10921/episodes/1/manifest.m3u8?quality=720');
    expect(session.tokenTtl, const Duration(minutes: 5));
  });
}
