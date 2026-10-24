import 'package:anistar_tv/packages/features/anime/domain/models/anime_episode.dart';
import 'package:anistar_tv/packages/features/anime/domain/models/anime_watch_action.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('watch action is empty when no episode is available', () {
    final action = selectAnimeWatchAction(const [], const {});

    expect(action.episode, isNull);
    expect(action.rewatch, isFalse);
  });

  test('watch action starts at the lowest available episode and skips watched gaps', () {
    final episodes = [
      const AnimeEpisode(number: 8, title: 'Восьмая'),
      const AnimeEpisode(number: 2, title: 'Вторая'),
      const AnimeEpisode(number: 5, title: 'Пятая'),
    ];

    expect(selectAnimeWatchAction(episodes, const {}).episode?.number, 2);
    expect(selectAnimeWatchAction(episodes, const {2}).episode?.number, 5);
    expect(selectAnimeWatchAction(episodes, const {2, 5}).episode?.number, 8);
  });

  test('server watched markers participate and a fully watched list restarts', () {
    final episodes = [
      const AnimeEpisode(number: 1, title: 'Первая', isWatched: true),
      const AnimeEpisode(number: 3, title: 'Третья'),
    ];

    final next = selectAnimeWatchAction(episodes, const {});
    expect(next.episode?.number, 3);
    expect(next.rewatch, isFalse);

    final restart = selectAnimeWatchAction(episodes, const {3});
    expect(restart.episode?.number, 1);
    expect(restart.rewatch, isTrue);
  });
}
