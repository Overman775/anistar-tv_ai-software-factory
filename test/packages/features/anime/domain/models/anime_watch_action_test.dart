import 'package:anistar_tv/packages/features/anime/anime_providers.dart';
import 'package:anistar_tv/packages/features/anime/domain/models/anime_episode.dart';
import 'package:anistar_tv/packages/features/anime/domain/models/anime_watch_action.dart';
import 'package:anistar_tv/packages/features/auth/auth_providers.dart';
import 'package:anistar_tv/packages/features/watch_history/watched_episodes.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../../mocks/features/anime/fake_anime_screen_repository.dart';

void main() {
  test('known episodes are scoped by exact identity and invalidate older or replacement loads', () {
    const first = AnimeEpisode(number: 2, title: 'Два');
    const second = AnimeEpisode(number: 8, title: 'Восемь');
    final container = ProviderContainer(
      overrides: [
        animeRepositoryProvider.overrideWithValue(const FakeAnimeScreenRepository()),
        authAccessProvider.overrideWithValue(const AuthenticatedAccess('first')),
        watchHistoryAccountProvider.overrideWithValue('first@origin-a'),
      ],
    );
    addTearDown(container.dispose);
    var snapshots = container.read(animeKnownEpisodesProvider);
    final old = snapshots.beginLoad(1, '1-title');
    old([second, first]);
    expect(snapshots.available(1, '1-title').map((item) => item.number), [8, 2]);
    expect(snapshots.available(2, '1-title'), isEmpty);
    expect(snapshots.available(1, '1-other'), isEmpty);
    final current = snapshots.beginLoad(1, '1-title');
    expect(snapshots.available(1, '1-title'), isEmpty);
    old([first]);
    expect(snapshots.available(1, '1-title'), isEmpty);
    current([second]);
    expect(snapshots.available(1, '1-title').single.number, 8);
    expect(() => snapshots.available(1, '1-title').clear(), throwsUnsupportedError);
    container.updateOverrides([
      animeRepositoryProvider.overrideWithValue(const FakeAnimeScreenRepository()),
      authAccessProvider.overrideWithValue(const AuthenticatedAccess('second')),
      watchHistoryAccountProvider.overrideWithValue('second@origin-b'),
    ]);
    snapshots = container.read(animeKnownEpisodesProvider);
    expect(snapshots.available(1, '1-title'), isEmpty);
    current([first]);
    expect(snapshots.available(1, '1-title'), isEmpty);
  });

  test('guest ignores server marks while confirmed marks choose numeric successor or replay', () {
    const episodes = [
      AnimeEpisode(number: 9, title: 'Девять', isWatched: true),
      AnimeEpisode(number: 2, title: 'Два', isWatched: true),
      AnimeEpisode(number: 5, title: 'Пять'),
    ];
    expect(selectAnimeWatchAction(episodes, const {}, includeEpisodeMarks: false).episode?.number, 2);
    expect(selectAnimeWatchAction(episodes, const {2, 5}).episode?.number, 2);
    expect(selectAnimeWatchAction(episodes, const {2, 5}).rewatch, isTrue);
  });

  for (final change in ['account', 'origin', 'repository']) {
    test('known list is discarded on independent $change replacement', () {
      final oldRepository = FakeAnimeScreenRepository(load: (_, _) async => throw StateError('not fetched'));
      final newRepository = FakeAnimeScreenRepository(load: (_, _) async => throw StateError('not fetched'));
      List<Override> scope(bool changed) => [
        animeRepositoryProvider.overrideWithValue(changed && change == 'repository' ? newRepository : oldRepository),
        authAccessProvider.overrideWithValue(
          changed && change == 'account' ? const AuthenticatedAccess('second') : const AuthenticatedAccess('first'),
        ),
        watchHistoryAccountProvider.overrideWithValue(
          changed && change == 'origin' ? 'first@origin-b' : 'first@origin-a',
        ),
      ];
      final container = ProviderContainer(overrides: scope(false));
      addTearDown(container.dispose);
      final old = container.read(animeKnownEpisodesProvider);
      final complete = old.beginLoad(1, '1-test');
      complete(const [AnimeEpisode(number: 5, title: 'Пять')]);
      expect(old.available(1, '1-test'), hasLength(1));
      container.updateOverrides(scope(true));
      final current = container.read(animeKnownEpisodesProvider);
      expect(current.available(1, '1-test'), isEmpty);
      complete(const [AnimeEpisode(number: 8, title: 'Восемь')]);
      expect(current.available(1, '1-test'), isEmpty);
    });
  }

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
