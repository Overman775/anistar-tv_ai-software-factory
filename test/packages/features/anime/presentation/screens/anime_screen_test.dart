import 'dart:async';

import 'package:anistar_tv/packages/features/anime/anime_providers.dart';
import 'package:anistar_tv/packages/features/anime/domain/models/anime_details.dart';
import 'package:anistar_tv/packages/features/anime/domain/models/anime_episode.dart';
import 'package:anistar_tv/packages/features/anime/domain/models/anime_screen_data.dart';
import 'package:anistar_tv/packages/features/anime/presentation/screens/anime_screen.dart';
import 'package:anistar_tv/packages/features/anime/presentation/widgets/anime_hero.dart';
import 'package:anistar_tv/packages/features/anime/presentation/widgets/episode_card.dart';
import 'package:anistar_tv/packages/features/catalog/domain/models/catalog_filter.dart';
import 'package:anistar_tv/packages/features/favorites/favorites_providers.dart';
import 'package:anistar_tv/packages/features/watch_history/watch_history_providers.dart';
import 'package:anistar_tv/packages/features/watch_history/watched_episodes.dart';
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
  testWidgets('empty episodes expose remote reload and can recover to playable data', (tester) async {
    var calls = 0;
    final repository = FakeAnimeScreenRepository(
      load: (id, slug) async {
        calls++;

        return calls == 1
            ? Result.success(
                AnimeScreenData(
                  details: AnimeDetails(id: 1, slug: 'test', title: 'Тест', genres: [], isOngoing: false),
                  episodes: [],
                ),
              )
            : const FakeAnimeScreenRepository().getAnime(id: id, slug: slug);
      },
    );
    await pumpTvApp(
      tester,
      AnimeScreen(animeId: 1, slug: 'test', fallbackTitle: 'Тест', onEpisodeTap: (_) => fail('Unexpected episode')),
      wrapInScaffold: false,
      overrides: [animeRepositoryProvider.overrideWithValue(repository)],
    );
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    final reload = find.widgetWithText(AppButton, 'Обновить серии');
    expect(reload.hitTestable(), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(find.widgetWithText(AppButton, 'Смотреть серию 1'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(find.byType(EpisodeCard), findsAtLeastNWidgets(1));
    expect(tester.takeException(), isNull);
  });
  testWidgets('unexpected detail error stays safe and remote retry recovers', (tester) async {
    var attempts = 0;
    final repository = FakeAnimeScreenRepository(
      load: (id, slug) {
        attempts++;
        if (attempts == 1) {
          throw StateError('https://cdn.test/private?token=secret');
        }

        return const FakeAnimeScreenRepository().getAnime(id: id, slug: slug);
      },
    );
    await pumpTvApp(
      tester,
      AnimeScreen(animeId: 1, slug: 'test', fallbackTitle: 'Тест', onEpisodeTap: (_) => fail('Unexpected episode')),
      wrapInScaffold: false,
      overrides: [animeRepositoryProvider.overrideWithValue(repository)],
    );
    await tester.pumpAndSettle();
    expect(find.text('Не удалось загрузить данные аниме. Повторите попытку.'), findsOneWidget);
    expect(find.textContaining('secret'), findsNothing);
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(attempts, 2);
    expect(find.byType(AnimeHero), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('obsolete detail response cannot overwrite latest favorite state', (tester) async {
    final pending = Completer<Result<AnimeScreenData, Failure>>();
    AnimeScreenData data(bool favorite) => AnimeScreenData(
      details: AnimeDetails(
        id: 1,
        slug: 'test',
        title: 'Тест',
        genres: const [],
        isOngoing: false,
        isFavorite: favorite,
      ),
      episodes: const [],
    );
    final repository = FakeAnimeScreenRepository(
      load: (_, slug) => slug == 'old' ? pending.future : Future.value(Result.success(data(false))),
    );
    AnimeScreen screen(String slug) =>
        AnimeScreen(animeId: 1, slug: slug, fallbackTitle: 'Тест', onEpisodeTap: (_) => fail('Unexpected episode'));
    final overrides = [animeRepositoryProvider.overrideWithValue(repository)];
    await pumpTvApp(tester, screen('old'), wrapInScaffold: false, overrides: overrides);
    await tester.pump();
    await pumpTvApp(tester, screen('new'), wrapInScaffold: false, overrides: overrides);
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(tester.element(find.byType(AnimeScreen)));
    final latestKnown = container.read(favoritesControllerProvider).known;
    expect(find.text('В избранное'), findsOneWidget);
    pending.complete(Result.success(data(true)));
    await tester.pumpAndSettle();
    expect(container.read(favoritesControllerProvider).known, latestKnown);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(find.text('Серии не найдены'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  for (final size in [compactTvSize, wideTvSize, const Size(640, 360)]) {
    for (final scale in [1.3, 2.0]) {
      testWidgets('scaled text $scale keeps hero actions visible and remote navigation at $size', (tester) async {
        int? opened;
        final data = AnimeScreenData(
          details: AnimeDetails(
            id: 1,
            slug: 'anime',
            title: 'Пожалуйста, простите моих младших братьев / Please Forgive My Younger Brothers',
            genres: const ['Комедия', 'Повседневность', 'Романтика'],
            isOngoing: true,
            posterUri: Uri(),
            year: '2026',
            seriesInfo: '14 серий',
            voiceover: 'Озвучивание: AniStar',
            description: List.filled(8, 'История о семье, дружбе и неожиданных приключениях.').join(' '),
          ),
          episodes: const [AnimeEpisode(number: 1, title: 'Серия 1')],
        );
        await pumpTvApp(
          tester,
          MediaQuery(
            data: MediaQueryData(size: size, disableAnimations: true, textScaler: TextScaler.linear(scale)),
            child: AnimeScreen(
              animeId: 1,
              slug: 'anime',
              fallbackTitle: data.details.title,
              onEpisodeTap: (episode) => opened = episode.number,
            ),
          ),
          size: size,
          wrapInScaffold: false,
          overrides: [
            animeRepositoryProvider.overrideWithValue(
              FakeAnimeScreenRepository(load: (_, _) async => Result.success(data)),
            ),
          ],
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final play = find.widgetWithText(AppButton, 'Смотреть серию 1');
        expect(FocusManager.instance.primaryFocus?.debugLabel, 'Смотреть первую серию');
        final initialPlayRect = tester.getRect(play);
        final focusContext = FocusManager.instance.primaryFocus?.context;
        final focusTarget = find.byElementPredicate((element) => identical(element, focusContext));
        final focusRect = tester.getRect(focusTarget);
        final viewportRect = tester.getRect(find.byType(Viewport).first);
        final playContext = tester.element(play);
        final scrollPosition = Scrollable.of(playContext).position;
        final initialPixels = scrollPosition.pixels;
        final minimum = scrollPosition.minScrollExtent;
        final maximum = scrollPosition.maxScrollExtent;
        final viewportExtent = scrollPosition.viewportDimension;
        final media = MediaQuery.of(playContext);
        expect(
          initialPlayRect.bottom,
          lessThanOrEqualTo(size.height),
          reason:
              'initial=$initialPlayRect focus=$focusRect viewport=$viewportRect '
              'scroll=$initialPixels min=$minimum max=$maximum extent=$viewportExtent '
              'media=${media.size} scaled18=${media.textScaler.scale(18)}',
        );
        expect(tester.getRect(play).top, greaterThanOrEqualTo(0));
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pumpAndSettle();
        expect(FocusManager.instance.primaryFocus?.debugLabel, 'Избранное сериала');
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
        expect(find.byType(EpisodeCard), findsOneWidget);
        final episodeRect = tester.getRect(find.byType(EpisodeCard));
        final episodeFocus = FocusManager.instance.primaryFocus;
        final episodeFocusTarget = find.byElementPredicate((element) => identical(element, episodeFocus?.context));
        final episodeFocusRect = tester.getRect(episodeFocusTarget);
        final episodePixels = scrollPosition.pixels;
        final episodeMaximum = scrollPosition.maxScrollExtent;
        expect(
          episodeRect.bottom,
          lessThanOrEqualTo(size.height),
          reason:
              'initialWatch=$initialPlayRect focus=$focusRect viewport=$viewportRect '
              'initialScroll=$initialPixels min=$minimum max=$maximum extent=$viewportExtent '
              'media=${media.size} scaled18=${media.textScaler.scale(18)} '
              'episode=$episodeRect focusLabel=${episodeFocus?.debugLabel} focusRect=$episodeFocusRect '
              'episodeScroll=$episodePixels max=$episodeMaximum',
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await tester.pumpAndSettle();
        // Recheck visibility after returning Up from the episode grid.
        expect(tester.getRect(play).bottom, lessThanOrEqualTo(size.height));
        await tester.sendKeyEvent(LogicalKeyboardKey.select);
        expect(opened, 1);
        // Navigation must not introduce a new layout exception.
        // ignore: avoid-duplicate-test-assertions
        expect(tester.takeException(), isNull);
      });
    }
  }

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
            load: (_, _) async => Result.success(
              AnimeScreenData(
                details: AnimeDetails(id: 1, slug: 'anime', title: 'Аниме', genres: [], isOngoing: false),
                episodes: [
                  const AnimeEpisode(number: 5, title: 'Серия 5'),
                  const AnimeEpisode(number: 1, title: 'Серия 1'),
                  const AnimeEpisode(number: 3, title: 'Серия 3'),
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
    expect(find.text('Посмотреть снова'), findsOneWidget);
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
    final playButton = find.widgetWithText(AppButton, 'Смотреть серию 1');
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
