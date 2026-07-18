import 'package:anistar_tv/packages/features/anime/data/repositories/anistar_anime_repository.dart';
import 'package:api/api.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';

void main() {
  test('loads detail and episodes into one screen model', () async {
    final dio = Dio(BaseOptions(baseUrl: 'http://parser.test'));
    final adapter = DioAdapter(dio: dio);
    adapter.onGet('/api/anime/10921-test-anime', (server) {
      server.reply(200, {
        'id': 10921,
        'slug': '10921-test-anime',
        'title': 'Тестовое аниме',
        'year': '2026',
        'genres': ['Приключения'],
        'voiceover': 'AniStar',
        'series_info': '12 эп.',
        'description': 'Описание',
        'is_ongoing': true,
        'poster_url': 'https://images.test/poster.jpg',
      });
    });
    adapter.onGet('/api/anime/10921/episodes', (server) {
      server.reply(200, [
        {
          'episode_number': 1,
          'title': 'Серия 1',
          'preview_url': 'https://images.test/episode.jpg',
          'playback_path': '/api/video/10921/episodes/1/playback',
        },
      ]);
    });
    final repository = AnistarAnimeRepository(AnimeClient(dio));

    final data = (await repository.getAnime(
      id: 10921,
      slug: '10921-test-anime',
    )).fold(onLeft: (failure) => fail(failure.message), onRight: (value) => value);

    expect(data.details.title, 'Тестовое аниме');
    expect(data.details.isOngoing, isTrue);
    expect(data.details.genres, ['Приключения']);
    expect(data.episodes.single.number, 1);
  });
}
