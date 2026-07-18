import 'package:anistar_tv/packages/features/anime/data/mappers/anime_screen_data_mapper.dart';
import 'package:api/api.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maps optional detail fields and normalizes an empty episode title', () {
    const detail = AnimeDetailDto(
      id: 17,
      slug: '17-test-title',
      title: 'Тестовое аниме',
      genres: ['Фэнтези'],
      posterUrl: 'invalid-url',
    );
    const episodes = [EpisodeInfoDto(episodeNumber: 4, title: '  ', playbackPath: '/api/video/17/episodes/4/playback')];

    final data = toAnimeScreenData(detail, episodes);
    final episode = data.episodes.single;

    expect(data.details.posterUri, isNull);
    expect(data.details.genres, ['Фэнтези']);
    expect(episode.title, 'Серия 4');
    expect(episode.previewUri, isNull);
  });

  test('sorts episodes and drops repeated episode numbers', () {
    const detail = AnimeDetailDto(id: 17, slug: '17-test-title', title: 'Тестовое аниме');
    const episodes = [
      EpisodeInfoDto(episodeNumber: 3, title: 'Третья', playbackPath: '/playback/3'),
      EpisodeInfoDto(episodeNumber: 1, title: 'Первая', playbackPath: '/playback/1'),
      EpisodeInfoDto(episodeNumber: 3, title: 'Дубликат', playbackPath: '/playback/3-copy'),
      EpisodeInfoDto(episodeNumber: 2, title: 'Вторая', playbackPath: '/playback/2'),
    ];

    final data = toAnimeScreenData(detail, episodes);

    expect(data.episodes.map((episode) => episode.number), [1, 2, 3]);
    expect(data.episodes.last.title, 'Третья');
  });
}
