import 'package:anistar_tv/packages/features/anime/anime_providers.dart';
import 'package:anistar_tv/packages/features/anime/domain/models/anime_details.dart';
import 'package:anistar_tv/packages/features/anime/domain/models/anime_episode.dart';
import 'package:anistar_tv/packages/features/anime/domain/models/anime_screen_data.dart';
import 'package:anistar_tv/packages/features/anime/presentation/screens/anime_screen.dart';
import 'package:anistar_tv/packages/features/anime/presentation/widgets/anime_hero.dart';
import 'package:anistar_tv/packages/features/anime/presentation/widgets/episode_card.dart';
import 'package:anistar_tv/packages/features/catalog/domain/models/catalog_filter.dart';
import 'package:anistar_tv/packages/features/watch_history/watched_episodes.dart';
import 'package:anistar_tv/packages/features/watch_history/watched_episodes_repository.dart';
import 'package:core/data.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';

import '../../../../../mocks/features/anime/fake_anime_screen_repository.dart';
import '../../../../../mocks/features/fake_watched_episodes_repository.dart';
import '../../../../../support/test_app.dart';

// Focus is mutable: each assertion reads the result of the preceding key event.
// ignore_for_file: prefer-moving-to-variable

void main() {
  testWidgets('watch action follows confirmed history, skips gaps and restarts after all episodes', (tester) async {
    final history = FakeWatchedEpisodesRepository()..watched[1] = {1};
    int? opened;
    await pumpTvApp(
      tester,
      AnimeScreen(
        animeId: 1,
        slug: 'anime',
        fallbackTitle: 'Аниме',
        onEpisodeTap: (episode) => opened = episode.number,
      ),
      overrides: [
        watchHistoryAccountProvider.overrideWithValue('tester'),
        watchedEpisodesRepositoryProvider.overrideWithValue(history),
        animeRepositoryProvider.overrideWithValue(
          FakeAnimeScreenRepository(
            load: (_, _) async => const Result.success(
              AnimeScreenData(
                details: AnimeDetails(id: 1, slug: 'anime', title: 'Аниме', genres: [], isOngoing: false),
                episodes: [
                  AnimeEpisode(number: 5, title: 'Серия 5'),
                  AnimeEpisode(number: 1, title: 'Серия 1'),
                  AnimeEpisode(number: 3, title: 'Серия 3'),
                ],
              ),
            ),
          ),
        ),
      ],
    );
    await tester.pumpAndSettle();
    expect(find.text('Смотреть серию 3'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    expect(opened, 3);
    final container = ProviderScope.containerOf(tester.element(find.byType(AnimeScreen)));
    await container.read(watchedEpisodesProvider(1).notifier).markStarted(3);
    await tester.pumpAndSettle();
    expect(find.text('Смотреть серию 5'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    expect(opened, 5);
    await container.read(watchedEpisodesProvider(1).notifier).markStarted(5);
    await tester.pumpAndSettle();
    expect(find.text('Смотреть серию 1'), findsOneWidget);
  });

  for (final size in [compactTvSize, wideTvSize, const Size(390, 844)]) {
    testWidgets('metadata row exposes every filter with D-pad and returns to the action at $size', (tester) async {
      final filters = List.generate(9, (index) => CatalogFilter(label: 'Длинный жанр $index', path: '/genre-$index/'));
      CatalogFilter? selected;
      await pumpTvApp(
        tester,
        AnimeScreen(
          animeId: 1,
          slug: '1-test',
          fallbackTitle: 'Аниме',
          onEpisodeTap: (_) => fail('Unexpected episode'),
          onFilterTap: (filter) => selected = filter,
        ),
        size: size,
        wrapInScaffold: false,
        overrides: [
          animeRepositoryProvider.overrideWithValue(
            FakeAnimeScreenRepository(
              load: (_, _) async => Result.success(
                AnimeScreenData(
                  details: AnimeDetails(
                    id: 1,
                    slug: '1-test',
                    title: 'Аниме',
                    genres: const [],
                    isOngoing: true,
                    filters: filters,
                    posterUri: Uri(),
                    isFavorite: false,
                  ),
                  episodes: const [AnimeEpisode(number: 1, title: 'Серия 1')],
                ),
              ),
            ),
          ),
        ],
      );
      await tester.pumpAndSettle();
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'Смотреть первую серию');
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'Длинный жанр 0');
      for (var i = 0; i < 9; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pumpAndSettle();
      }
      expect(selected, isNull);
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'Длинный жанр 8');
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      expect(selected?.path, '/genre-8/');
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      // Recheck focus after each directional transition.
      // ignore: avoid-duplicate-test-assertions
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'Смотреть первую серию');
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();
      // Recheck restored focus after leaving the metadata row.
      // ignore: avoid-duplicate-test-assertions
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'Длинный жанр 8');
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('poster layout enters the latest episode and restores visible hero focus from a long grid', (
    tester,
  ) async {
    final key = tester.sendKeyEvent;
    final settle = tester.pumpAndSettle;
    String? focusedLabel() => FocusManager.instance.primaryFocus?.debugLabel;
    int? opened;
    await pumpTvApp(
      tester,
      AnimeScreen(
        animeId: 1,
        slug: 'anime',
        fallbackTitle: 'Аниме',
        onEpisodeTap: (episode) => opened = episode.number,
      ),
      size: wideTvSize,
      wrapInScaffold: false,
      overrides: [
        animeRepositoryProvider.overrideWithValue(
          FakeAnimeScreenRepository(
            load: (_, _) async => Result.success(
              AnimeScreenData(
                details: AnimeDetails(
                  id: 1,
                  slug: 'anime',
                  title: 'Аниме',
                  genres: const [],
                  isOngoing: false,
                  posterUri: Uri.parse('https://image.test/poster.jpg'),
                  isFavorite: false,
                ),
                episodes: List.generate(32, (index) => AnimeEpisode(number: index + 1, title: 'Серия ${index + 1}')),
              ),
            ),
          ),
        ),
      ],
    );
    await settle();
    await key(LogicalKeyboardKey.arrowRight);
    await settle();
    expect(focusedLabel(), 'Избранное сериала');
    await key(LogicalKeyboardKey.arrowDown);
    await settle();
    await key(LogicalKeyboardKey.select);
    expect(opened, 32);
    for (var row = 0; row < 5; row++) {
      await key(LogicalKeyboardKey.arrowDown);
      await settle();
    }
    final focus = FocusManager.instance.primaryFocus;
    final cardContext = focus?.context?.findAncestorWidgetOfExactType<EpisodeCard>();
    expect(cardContext?.episode.number, lessThan(32));
    for (var row = 0; row < 6; row++) {
      await key(LogicalKeyboardKey.arrowUp);
      await settle();
    }
    expect(focusedLabel(), 'Смотреть первую серию');
    final scroll = tester.widget<CustomScrollView>(find.byType(CustomScrollView)).controller;
    expect(scroll?.offset, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('changing route parameters loads the new anime in the existing State', (tester) async {
    final requests = <int>[];
    final repository = FakeAnimeScreenRepository(
      load: (id, slug) {
        requests.add(id);

        return const FakeAnimeScreenRepository().getAnime(id: id, slug: slug);
      },
    );
    AnimeScreen screen(int id) => AnimeScreen(
      animeId: id,
      slug: '$id-anime',
      fallbackTitle: 'Аниме $id',
      onEpisodeTap: (episode) => expect(episode.number, isPositive),
    );
    final pumpAndSettle = tester.pumpAndSettle;
    final screenFinder = find.byType(AnimeScreen);
    final stateOf = tester.state;
    final overrides = [animeRepositoryProvider.overrideWithValue(repository)];
    await pumpTvApp(tester, screen(1), wrapInScaffold: false, overrides: overrides);
    await pumpAndSettle();
    final state = stateOf(screenFinder);
    await pumpTvApp(tester, screen(2), wrapInScaffold: false, overrides: overrides);
    await pumpAndSettle();
    expect(stateOf(screenFinder), same(state));
    expect(requests, [1, 2]);
    expect(find.byType(AnimeHero), findsOneWidget);
  });

  testWidgets('keeps the hero action visible and moves focus to episodes on a compact TV', (tester) async {
    int? openedEpisode;
    await pumpTvApp(
      tester,
      AnimeScreen(
        animeId: 1,
        slug: 'test-anime',
        fallbackTitle: 'Тестовое аниме',
        onEpisodeTap: (episode) => openedEpisode = episode.number,
      ),
      wrapInScaffold: false,
      overrides: [animeRepositoryProvider.overrideWithValue(const FakeAnimeScreenRepository())],
    );
    final pumpAndSettle = tester.pumpAndSettle;
    final sendKeyEvent = tester.sendKeyEvent;
    await pumpAndSettle();
    final playButton = find.widgetWithText(FilledButton, 'Смотреть серию 1');
    expect(playButton, findsOneWidget);
    expect(tester.getBottomRight(playButton).dy, lessThanOrEqualTo(540));
    expect(tester.takeException(), isNull);
    await sendKeyEvent(LogicalKeyboardKey.select);
    expect(openedEpisode, 1);
    await sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await pumpAndSettle();
    expect(tester.widgetList<EpisodeCard>(find.byType(EpisodeCard)).map((card) => card.episode.number), [3, 2, 1]);
    await sendKeyEvent(LogicalKeyboardKey.select);
    expect(openedEpisode, 3);
    await sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump(AppMotion.fast);
    await sendKeyEvent(LogicalKeyboardKey.select);
    expect(openedEpisode, 2);
  });
}
