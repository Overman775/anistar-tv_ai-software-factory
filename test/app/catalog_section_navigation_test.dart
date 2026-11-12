// Assertions observe identities and focus again after each section transition.

import 'dart:async';

import 'package:anistar_tv/app/app_router.dart';
import 'package:anistar_tv/app/app_routes.dart';
import 'package:anistar_tv/packages/features/anime/anime_providers.dart';
import 'package:anistar_tv/packages/features/anime/domain/models/anime_details.dart';
import 'package:anistar_tv/packages/features/anime/domain/models/anime_episode.dart';
import 'package:anistar_tv/packages/features/anime/domain/models/anime_screen_data.dart';
import 'package:anistar_tv/packages/features/anime/presentation/screens/anime_screen.dart';
import 'package:anistar_tv/packages/features/auth/auth_providers.dart';
import 'package:anistar_tv/packages/features/catalog/catalog_providers.dart';
import 'package:anistar_tv/packages/features/catalog/domain/models/anime_page.dart';
import 'package:anistar_tv/packages/features/catalog/domain/models/anime_summary.dart';
import 'package:anistar_tv/packages/features/catalog/domain/models/catalog_filter.dart';
import 'package:anistar_tv/packages/features/catalog/presentation/screens/catalog_screen.dart';
import 'package:anistar_tv/packages/features/catalog/presentation/widgets/anime_card.dart';
import 'package:anistar_tv/packages/features/catalog/presentation/widgets/catalog_inspector_copy.dart';
import 'package:anistar_tv/packages/features/catalog/presentation/widgets/catalog_navigation_rail.dart';
import 'package:anistar_tv/packages/features/catalog/presentation/widgets/catalog_poster_rail.dart';
import 'package:anistar_tv/packages/features/favorites/favorites_providers.dart';
import 'package:anistar_tv/packages/features/home/presentation/home_destination.dart';
import 'package:anistar_tv/packages/features/home/presentation/screens/home_screen.dart';
import 'package:anistar_tv/packages/features/player/domain/models/playback_session.dart';
import 'package:anistar_tv/packages/features/player/player_providers.dart';
import 'package:anistar_tv/packages/features/player/presentation/screens/player_screen.dart';
import 'package:anistar_tv/packages/features/search/presentation/search_screen.dart';
import 'package:anistar_tv/packages/features/search/search_providers.dart';
import 'package:anistar_tv/packages/features/watch_history/watch_history_providers.dart';
import 'package:anistar_tv/packages/features/watch_history/watched_episodes.dart';
import 'package:app_logging/app_logging.dart';
import 'package:core/data.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';

import '../mocks/features/anime/fake_anime_screen_repository.dart';
import '../mocks/features/catalog/fake_catalog_browse_repository.dart';
import '../mocks/features/catalog/fake_catalog_screen_repository.dart';
import '../mocks/features/fake_watched_episodes_repository.dart';
import '../mocks/features/favorites/fake_favorites_repository.dart';
import '../mocks/features/player/fake_playback_repository.dart';
import '../mocks/features/search/fake_search_repository.dart';
import '../support/test_app.dart';

FakeCatalogScreenRepository _nonFavoriteCatalog() => FakeCatalogScreenRepository(
  load: (page) async => Result.success(
    AnimePage(
      items: List.generate(
        12,
        (index) =>
            AnimeSummary(id: index + 1, slug: '${index + 1}-anime', title: 'Аниме ${index + 1}', isFavorite: false),
      ),
      page: page,
      hasNext: false,
    ),
  ),
);

void main() {
  for (final (guest, marks, target) in <(bool, Set<int>, int)>[
    (false, {}, 2),
    (false, {2}, 5),
    (false, {2, 5, 8}, 2),
    (true, {2, 5, 8}, 2),
  ]) {
    testWidgets('Home Watch fallback then episode $target guest=$guest marks=$marks', (tester) async {
      final router = AppRouter(AppLogger.logger);
      addTearDown(router.dispose);
      var detailReads = 0;
      final details = FakeAnimeScreenRepository(
        load: (id, slug) async {
          detailReads++;
          return Result.success(
            AnimeScreenData(
              details: AnimeDetails(id: id, slug: slug, title: 'Тест', genres: const [], isOngoing: false),
              episodes: [
                AnimeEpisode(number: 8, title: 'Восемь', isWatched: guest),
                const AnimeEpisode(number: 2, title: 'Два'),
                const AnimeEpisode(number: 5, title: 'Пять'),
              ],
            ),
          );
        },
      );
      final watched = FakeWatchedEpisodesRepository()..watched[1] = marks;
      final playback = FakePlaybackRepository()..pending = Completer<Result<PlaybackSession, Failure>>();
      final catalog = FakeCatalogScreenRepository(
        load: (page) async => Result.success(
          AnimePage(
            items: const [AnimeSummary(id: 1, slug: '1-test', title: 'Тест')],
            page: page,
            hasNext: false,
          ),
        ),
      );
      await pumpTvApp(
        tester,
        MaterialApp.router(routerConfig: router.router, theme: AppTheme.darkTheme),
        wrapInScaffold: false,
        overrides: [
          authAccessProvider.overrideWithValue(guest ? const AnonymousAccess() : const AuthenticatedAccess('test')),
          favoritesAccountProvider.overrideWithValue(guest ? null : 'test'),
          watchHistoryAccountProvider.overrideWithValue(guest ? null : 'test@origin'),
          watchedEpisodesRepositoryProvider.overrideWithValue(watched),
          animeRepositoryProvider.overrideWithValue(details),
          playbackRepositoryProvider.overrideWithValue(playback),
          catalogRepositoryProvider.overrideWithValue(catalog),
          favoritesRepositoryProvider.overrideWithValue(FakeFavoritesRepository()),
        ],
      );
      await tester.pumpAndSettle();
      final poster = FocusManager.instance.primaryFocus;
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();
      expect(focusedControlLabel(tester), 'Смотреть');
      expect(detailReads, 0);
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pumpAndSettle();
      expect(find.byType(AnimeScreen), findsOneWidget);
      expect(detailReads, 1);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(FocusManager.instance.primaryFocus, same(poster));
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pumpAndSettle();
      expect(find.byType(AnimeScreen), findsOneWidget, reason: 'poster OK remains a detail route');
      expect(detailReads, 2);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(PlayerScreen), findsOneWidget);
      final player = tester.widget<PlayerScreen>(find.byType(PlayerScreen));
      expect((player.animeId, player.episodeNumber), (1, target));
      expect(detailReads, 2, reason: 'Watch does not fetch details speculatively');
      await tester.binding.handlePopRoute();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(FocusManager.instance.primaryFocus, same(poster));
      expect(tester.takeException(), isNull);
    });
  }

  for (final source in ['favorites', 'search', 'filter']) {
    testWidgets('$source Watch opens known episode and restores its poster', (tester) async {
      final router = AppRouter(AppLogger.logger);
      addTearDown(router.dispose);
      var reads = 0;
      final details = FakeAnimeScreenRepository(
        load: (id, slug) async {
          reads++;
          return Result.success(
            AnimeScreenData(
              details: AnimeDetails(id: id, slug: slug, title: 'Тест', genres: const [], isOngoing: false),
              episodes: const [
                AnimeEpisode(number: 8, title: 'Восемь'),
                AnimeEpisode(number: 2, title: 'Два'),
                AnimeEpisode(number: 5, title: 'Пять'),
              ],
            ),
          );
        },
      );
      final items = List.generate(
        16,
        (i) => AnimeSummary(id: i + 1, slug: '${i + 1}-test', title: i == 0 ? 'Тест' : 'Аниме ${i + 1}'),
      );
      final catalog = FakeCatalogScreenRepository(
        load: (page) async => Result.success(AnimePage(items: items, page: page, hasNext: false)),
      );
      final browse = FakeCatalogBrowseRepository(
        load: (_, page) async => Result.success(AnimePage(items: items, page: page, hasNext: false)),
      );
      final favorites = FakeFavoritesRepository()
        ..load = (page) async => Result.success(AnimePage(items: items, page: page, hasNext: false));
      final search = FakeSearchRepository(
        load: (request) async => Result.success(AnimePage(items: items, page: request.page, hasNext: false)),
      );
      final watched = FakeWatchedEpisodesRepository()..watched[1] = {2};
      final playback = FakePlaybackRepository()..pending = Completer<Result<PlaybackSession, Failure>>();
      await pumpTvApp(
        tester,
        MaterialApp.router(routerConfig: router.router, theme: AppTheme.darkTheme),
        wrapInScaffold: false,
        overrides: [
          authAccessProvider.overrideWithValue(const AuthenticatedAccess('test')),
          favoritesAccountProvider.overrideWithValue('test'),
          watchHistoryAccountProvider.overrideWithValue('test@origin'),
          watchedEpisodesRepositoryProvider.overrideWithValue(watched),
          animeRepositoryProvider.overrideWithValue(details),
          playbackRepositoryProvider.overrideWithValue(playback),
          catalogRepositoryProvider.overrideWithValue(catalog),
          catalogBrowseRepositoryProvider.overrideWithValue(browse),
          favoritesRepositoryProvider.overrideWithValue(favorites),
          searchRepositoryProvider.overrideWithValue(search),
          searchHistoryRepositoryProvider.overrideWithValue(FakeSearchHistoryRepository()),
        ],
      );
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pumpAndSettle();
      expect(find.byType(AnimeScreen), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      if (source == 'favorites') {
        const HomeRoute(destination: HomeDestination.favorites).go(tester.element(find.byType(HomeScreen)));
        await tester.pumpAndSettle();
      } else if (source == 'search') {
        const HomeRoute(destination: HomeDestination.search).go(tester.element(find.byType(HomeScreen)));
        await tester.pumpAndSettle();
        await tester.enterText(find.byKey(const ValueKey('search-query')), 'Наруто');
        await tester.testTextInput.receiveAction(TextInputAction.search);
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
      } else {
        unawaited(
          const FilterRoute(
            path: '/filter/author/%f1%E8+%fd/',
            title: 'Автор',
            destination: HomeDestination.home,
          ).push<void>(tester.element(find.byType(HomeScreen))),
        );
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
      }
      final poster = FocusManager.instance.primaryFocus;
      final scroll = tester.widget<CatalogPosterRail>(find.byType(CatalogPosterRail)).controller..jumpTo(17);
      await tester.pump();
      final offset = scroll.offset;
      expect(offset, 17);
      expect(poster?.context?.findAncestorWidgetOfExactType<AnimeCard>()?.anime.id, 1);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();
      expect(focusedControlLabel(tester), 'Смотреть');
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      final player = tester.widget<PlayerScreen>(find.byType(PlayerScreen));
      expect((player.animeId, player.episodeNumber), (1, 5));
      expect(reads, 1);
      await tester.binding.handlePopRoute();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(FocusManager.instance.primaryFocus, same(poster));
      expect(scroll.offset, offset);
      if (source == 'search') {
        expect(tester.widget<TextField>(find.byKey(const ValueKey('search-query'))).controller?.text, 'Наруто');
        expect(search.requests, hasLength(1));
      }
      expect(tester.takeException(), isNull);
    });
  }

  for (final fadeIn in [false, true]) {
    testWidgets('Watch during fade resolves the current selected title fadeIn=$fadeIn', (tester) async {
      final router = AppRouter(AppLogger.logger);
      addTearDown(router.dispose);
      var reads = 0;
      final details = FakeAnimeScreenRepository(
        load: (_, _) async {
          reads++;
          throw StateError('no speculative load');
        },
      );
      final playback = FakePlaybackRepository()..pending = Completer<Result<PlaybackSession, Failure>>();
      final catalog = FakeCatalogScreenRepository(
        load: (page) async => Result.success(
          AnimePage(
            items: const [
              AnimeSummary(id: 1, slug: '1-test', title: 'Первый'),
              AnimeSummary(id: 2, slug: '2-test', title: 'Второй'),
            ],
            page: page,
            hasNext: false,
          ),
        ),
      );
      await pumpTvApp(
        tester,
        MaterialApp.router(routerConfig: router.router, theme: AppTheme.darkTheme),
        wrapInScaffold: false,
        overrides: [
          authAccessProvider.overrideWithValue(const AnonymousAccess()),
          animeRepositoryProvider.overrideWithValue(details),
          playbackRepositoryProvider.overrideWithValue(playback),
          catalogRepositoryProvider.overrideWithValue(catalog),
          favoritesRepositoryProvider.overrideWithValue(FakeFavoritesRepository()),
        ],
      );
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(tester.element(find.byType(HomeScreen)));
      container.read(animeKnownEpisodesProvider).beginLoad(2, '2-test')(const [AnimeEpisode(number: 5, title: 'Пять')]);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      if (fadeIn) {
        await tester.pump(const Duration(milliseconds: 111));
        await tester.pump();
      }
      await tester.pump(const Duration(milliseconds: 50));
      final copy = tester.widget<CatalogInspectorCopy>(find.byType(CatalogInspectorCopy));
      expect(copy.opacity.value, inExclusiveRange(0, 1));
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      final player = tester.widget<PlayerScreen>(find.byType(PlayerScreen));
      expect((player.animeId, player.episodeNumber), (2, 5));
      expect(reads, 0);
      expect(tester.takeException(), isNull);
    });
  }

  for (final scenario in ['empty', 'pending', 'wrong-slug']) {
    testWidgets('Watch falls back to details for $scenario episode snapshot', (tester) async {
      final router = AppRouter(AppLogger.logger);
      addTearDown(router.dispose);
      var reads = 0;
      final details = FakeAnimeScreenRepository(
        load: (id, slug) async {
          reads++;
          return Result.success(
            AnimeScreenData(
              details: AnimeDetails(id: id, slug: slug, title: 'Тест', genres: const [], isOngoing: false),
              episodes: const [AnimeEpisode(number: 5, title: 'Пять')],
            ),
          );
        },
      );
      final catalog = FakeCatalogScreenRepository(
        load: (page) async => Result.success(
          AnimePage(
            items: const [AnimeSummary(id: 1, slug: '1-test', title: 'Тест')],
            page: page,
            hasNext: false,
          ),
        ),
      );
      await pumpTvApp(
        tester,
        MaterialApp.router(routerConfig: router.router, theme: AppTheme.darkTheme),
        wrapInScaffold: false,
        overrides: [
          authAccessProvider.overrideWithValue(const AnonymousAccess()),
          animeRepositoryProvider.overrideWithValue(details),
          catalogRepositoryProvider.overrideWithValue(catalog),
          favoritesRepositoryProvider.overrideWithValue(FakeFavoritesRepository()),
        ],
      );
      await tester.pumpAndSettle();
      final snapshots = ProviderScope.containerOf(tester.element(find.byType(HomeScreen)))
          .read(animeKnownEpisodesProvider);
      if (scenario == 'wrong-slug') {
        snapshots.beginLoad(1, '1-other')(const [AnimeEpisode(number: 5, title: 'Пять')]);
      } else {
        snapshots.beginLoad(1, '1-test')(
          scenario == 'pending' ? const [AnimeEpisode(number: 5, title: 'Пять')] : const [],
        );
        if (scenario == 'pending') snapshots.beginLoad(1, '1-test');
      }
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();
      expect(reads, 0);
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pumpAndSettle();
      expect(find.byType(AnimeScreen), findsOneWidget);
      expect(find.byType(PlayerScreen), findsNothing);
      expect(reads, 1);
      expect(tester.takeException(), isNull);
    });
  }

  for (final reducedMotion in [false, true]) {
    testWidgets('menu arrows defer selection and OK collapses into retained section content (reduced=$reducedMotion)', (
      tester,
    ) async {
      final favorites = FakeFavoritesRepository()..ids.add(20);
      await pumpTvApp(
        tester,
        MediaQuery(
          data: MediaQueryData(disableAnimations: reducedMotion),
          child: HomeScreen(accountName: 'test', onAnimeTap: (_) => fail('Unexpected detail')),
        ),
        wrapInScaffold: false,
        overrides: [
          authAccessProvider.overrideWithValue(const AuthenticatedAccess('test')),
          favoritesAccountProvider.overrideWithValue('test'),
          catalogRepositoryProvider.overrideWithValue(_nonFavoriteCatalog()),
          favoritesRepositoryProvider.overrideWithValue(favorites),
        ],
      );
      await tester.pumpAndSettle();
      final rail = find.byType(CatalogNavigationRail);
      final railElement = tester.element(rail);
      final homeState = tester.state(find.byType(CatalogScreen));
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      for (var step = 0; step < 2; step++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pump();
      }
      expect(focusedControlLabel(tester), 'Избранное');
      expect(favorites.pages, isEmpty);
      expect(tester.widget<CatalogNavigationRail>(rail).expanded, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pumpAndSettle();
      expect(tester.widget<CatalogNavigationRail>(rail).expanded, isFalse);
      expect(FocusManager.instance.primaryFocus?.context?.findAncestorWidgetOfExactType<AnimeCard>()?.anime.id, 20);
      expect(tester.element(rail), same(railElement));
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      // Root Back must restore the previously active menu target and expansion.
      expect(focusedControlLabel(tester), 'Избранное');
      expect(tester.widget<CatalogNavigationRail>(rail).expanded, isTrue);
      for (var step = 0; step < 2; step++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await tester.pump();
      }
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pumpAndSettle();
      expect(tester.state(find.byType(CatalogScreen)), same(homeState));
      expect(FocusManager.instance.primaryFocus?.context?.findAncestorWidgetOfExactType<AnimeCard>(), isNotNull);
      expect(favorites.pages, [1]);
      expect(tester.takeException(), isNull);
    });
  }

  for (final source in ['home', 'favorites', 'filter']) {
    testWidgets('$source Watch return restores non-anchor offset, selection and focus without reloading', (
      tester,
    ) async {
      const author = CatalogFilter(label: 'Автор', path: '/filter/author/%f1%E8+%fd/');
      final items = List.generate(16, (i) => AnimeSummary(id: i + 1, slug: '${i + 1}-test', title: 'Аниме ${i + 1}'));
      var catalogRequests = 0;
      final catalog = FakeCatalogScreenRepository(
        load: (page) async {
          catalogRequests++;
          return Result.success(AnimePage(items: items, page: page, hasNext: false));
        },
      );
      final browse = FakeCatalogBrowseRepository(
        load: (_, page) async => Result.success(AnimePage(items: items, page: page, hasNext: false)),
      );
      final favorites = FakeFavoritesRepository()
        ..load = (page) async => Result.success(AnimePage(items: items, page: page, hasNext: false));
      await pumpTvApp(
        tester,
        Builder(
          builder: (context) => CatalogScreen(
            favoritesOnly: source == 'favorites',
            filter: source == 'filter' ? author : null,
            onAnimeTap: (anime) => unawaited(
              Navigator.of(context).push<void>(MaterialPageRoute(builder: (_) => Text('Детали ${anime.id}'))),
            ),
          ),
        ),
        wrapInScaffold: false,
        overrides: [
          authAccessProvider.overrideWithValue(const AuthenticatedAccess('test')),
          favoritesAccountProvider.overrideWithValue('test'),
          catalogRepositoryProvider.overrideWithValue(catalog),
          catalogBrowseRepositoryProvider.overrideWithValue(browse),
          favoritesRepositoryProvider.overrideWithValue(favorites),
        ],
      );
      await tester.pumpAndSettle();
      if (source == 'filter') {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
      }
      for (var i = 0; i < 5; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pumpAndSettle();
      }
      final selected = FocusManager.instance.primaryFocus;
      final id = selected?.context?.findAncestorWidgetOfExactType<AnimeCard>()?.anime.id;
      expect(id, isNotNull);
      final scroll = tester.widget<CatalogPosterRail>(find.byType(CatalogPosterRail)).controller;
      scroll.jumpTo(scroll.offset + 17);
      await tester.pump();
      final offset = scroll.offset;
      expect(offset, isPositive);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();
      expect(focusedControlLabel(tester), 'Смотреть');
      expect(tester.widget<CatalogInspectorCopy>(find.byType(CatalogInspectorCopy)).anime.id, id);
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pumpAndSettle();
      expect(find.text('Детали $id'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(FocusManager.instance.primaryFocus, same(selected));
      expect(scroll.offset, offset);
      expect(tester.widget<CatalogInspectorCopy>(find.byType(CatalogInspectorCopy)).anime.id, id);
      final requests = switch (source) {
        'home' => catalogRequests,
        'filter' => browse.requests.length,
        _ => favorites.pages.length,
      };
      expect(requests, 1);
      if (source == 'filter') expect(browse.requests, [(author.path, 1)]);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('switching TV sections retains each rail and search query', (tester) async {
    final items = List.generate(16, (i) => AnimeSummary(id: i + 1, slug: '${i + 1}-test', title: 'Аниме ${i + 1}'));
    var homeRequests = 0;
    final catalog = FakeCatalogScreenRepository(
      load: (page) async {
        homeRequests++;
        return Result.success(AnimePage(items: items, page: page, hasNext: false));
      },
    );
    final favorites = FakeFavoritesRepository()
      ..load = (page) async => Result.success(AnimePage(items: items, page: page, hasNext: false));
    final search = FakeSearchRepository(
      load: (request) async => Result.success(AnimePage(items: items, page: request.page, hasNext: false)),
    );
    await pumpTvApp(
      tester,
      HomeScreen(onAnimeTap: (_) => fail('Unexpected detail')),
      wrapInScaffold: false,
      overrides: [
        authAccessProvider.overrideWithValue(const AuthenticatedAccess('test')),
        favoritesAccountProvider.overrideWithValue('test'),
        catalogRepositoryProvider.overrideWithValue(catalog),
        favoritesRepositoryProvider.overrideWithValue(favorites),
        searchRepositoryProvider.overrideWithValue(search),
        searchHistoryRepositoryProvider.overrideWithValue(FakeSearchHistoryRepository()),
      ],
    );
    await tester.pumpAndSettle();
    Future<void> key(LogicalKeyboardKey value) async {
      await tester.sendKeyEvent(value);
      await tester.pumpAndSettle();
    }

    Future<void> section(String name) async {
      await key(LogicalKeyboardKey.escape);
      await tester.tap(find.byKey(ValueKey(name)));
      await tester.pumpAndSettle();
    }

    for (var i = 0; i < 4; i++) {
      await key(LogicalKeyboardKey.arrowRight);
    }
    final homeFocus = FocusManager.instance.primaryFocus;
    final homeScroll = tester.widget<CatalogPosterRail>(find.byType(CatalogPosterRail)).controller;
    homeScroll.jumpTo(homeScroll.offset + 13);
    await tester.pump();
    final homeOffset = homeScroll.offset;
    await key(LogicalKeyboardKey.escape);
    await key(LogicalKeyboardKey.arrowRight);
    expect(FocusManager.instance.primaryFocus, same(homeFocus));
    expect(homeScroll.offset, homeOffset);
    await section('catalog-tab-true');
    for (var i = 0; i < 3; i++) {
      await key(LogicalKeyboardKey.arrowRight);
    }
    final favoriteFocus = FocusManager.instance.primaryFocus;
    final favoriteScroll = tester.widget<CatalogPosterRail>(find.byType(CatalogPosterRail)).controller;
    favoriteScroll.jumpTo(favoriteScroll.offset + 11);
    await tester.pump();
    final favoriteOffset = favoriteScroll.offset;
    await section('catalog-search');
    await tester.enterText(find.byKey(const ValueKey('search-query')), 'Наруто');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    await key(LogicalKeyboardKey.arrowDown);
    for (var i = 0; i < 2; i++) {
      await key(LogicalKeyboardKey.arrowRight);
    }
    final searchFocus = FocusManager.instance.primaryFocus;
    final searchScroll = tester.widget<CatalogPosterRail>(find.byType(CatalogPosterRail)).controller;
    final searchOffset = searchScroll.offset;
    await section('catalog-genres');
    expect(find.byType(SearchScreen), findsNothing);
    await section('catalog-tab-false');
    expect(FocusManager.instance.primaryFocus, same(homeFocus));
    expect(homeScroll.offset, homeOffset);
    await section('catalog-tab-true');
    expect(FocusManager.instance.primaryFocus, same(favoriteFocus));
    expect(favoriteScroll.offset, favoriteOffset);
    await section('catalog-search');
    expect(searchScroll.offset, searchOffset);
    expect(tester.widget<TextField>(find.byKey(const ValueKey('search-query'))).controller?.text, 'Наруто');
    expect(search.requests, hasLength(1));
    expect(homeRequests, 2);
    expect(favorites.pages.length, greaterThanOrEqualTo(2));
    expect(FocusManager.instance.primaryFocus, same(searchFocus));
    expect(tester.takeException(), isNull);
  });

  for (final removed in [3, 4]) {
    testWidgets('refresh selects nearest remaining poster after removing $removed', (tester) async {
      var ids = [1, 2, 3, 4];
      final repository = FakeCatalogScreenRepository(
        load: (page) async => Result.success(
          AnimePage(
            items: [for (final id in ids) AnimeSummary(id: id, slug: '$id-test', title: 'Аниме $id')],
            page: page,
            hasNext: false,
          ),
        ),
      );
      await pumpTvApp(
        tester,
        CatalogScreen(onAnimeTap: (_) => fail('Unexpected activation')),
        wrapInScaffold: false,
        overrides: [
          authAccessProvider.overrideWithValue(const AnonymousAccess()),
          catalogRepositoryProvider.overrideWithValue(repository),
        ],
      );
      await tester.pumpAndSettle();
      for (var i = 1; i < removed; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pumpAndSettle();
      }
      await tester.pumpAndSettle();
      int? focusedId() =>
          FocusManager.instance.primaryFocus?.context?.findAncestorWidgetOfExactType<AnimeCard>()?.anime.id;
      expect(focusedId(), removed);
      ids = [
        for (final id in ids)
          if (id != removed) id,
      ];
      tester.state<CatalogScreenState>(find.byType(CatalogScreen)).refresh();
      await tester.pumpAndSettle();
      expect(focusedId(), removed == 3 ? 4 : 3);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('second empty favorites activation retains its content action after asynchronous refresh', (
    tester,
  ) async {
    final refreshed = Completer<Result<AnimePage, Failure>>();
    final favorites = FakeFavoritesRepository();
    await pumpTvApp(
      tester,
      HomeScreen(onAnimeTap: (_) => fail('Unexpected detail')),
      wrapInScaffold: false,
      overrides: [
        authAccessProvider.overrideWithValue(const AuthenticatedAccess('test')),
        favoritesAccountProvider.overrideWithValue('test'),
        catalogRepositoryProvider.overrideWithValue(_nonFavoriteCatalog()),
        favoritesRepositoryProvider.overrideWithValue(favorites),
      ],
    );
    final settle = tester.pumpAndSettle;
    final key = tester.sendKeyEvent;
    Future<void> openFavorites() async {
      await key(LogicalKeyboardKey.arrowLeft);
      await settle();
      for (var step = 0; step < 2; step++) {
        await key(LogicalKeyboardKey.arrowDown);
        await tester.pump();
      }
      await key(LogicalKeyboardKey.select);
      await tester.pump();
    }

    void expectContentAction() {
      final action = tester.widget<AppButton>(find.widgetWithText(AppButton, 'Перейти на главную'));
      expect(FocusManager.instance.primaryFocus?.context?.findAncestorWidgetOfExactType<AppButton>(), same(action));
      expect(tester.widget<CatalogNavigationRail>(find.byType(CatalogNavigationRail)).expanded, isFalse);
    }

    await settle();
    await openFavorites();
    await settle();
    expectContentAction();
    await tester.binding.handlePopRoute();
    await settle();
    for (var step = 0; step < 2; step++) {
      await key(LogicalKeyboardKey.arrowUp);
      await tester.pump();
    }
    await key(LogicalKeyboardKey.select);
    await settle();
    favorites.load = (_) => refreshed.future;
    await openFavorites();
    await tester.pump(const Duration(milliseconds: 300));
    expectContentAction();
    refreshed.complete(Result.success(AnimePage(items: [], page: 1, hasNext: false)));
    await settle();
    expectContentAction();
    expect(favorites.pages, [1, 1]);
    await key(LogicalKeyboardKey.select);
    await settle();
    expect(find.byType(AnimeCard), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('retained Home rereads site favorites on section activation and clears the temporary display cache', (
    tester,
  ) async {
    var favoriteOnSite = false;
    final requests = <int>[];
    await pumpTvApp(
      tester,
      HomeScreen(onAnimeTap: (_) => fail('Unexpected detail')),
      wrapInScaffold: false,
      overrides: [
        authAccessProvider.overrideWithValue(const AuthenticatedAccess('test')),
        favoritesAccountProvider.overrideWithValue('test'),
        catalogRepositoryProvider.overrideWithValue(
          FakeCatalogScreenRepository(
            load: (page) async {
              requests.add(page);

              return Result.success(
                AnimePage(
                  items: [AnimeSummary(id: 1, slug: '1-anime', title: 'Аниме 1', isFavorite: favoriteOnSite)],
                  page: page,
                  hasNext: false,
                ),
              );
            },
          ),
        ),
        favoritesRepositoryProvider.overrideWithValue(FakeFavoritesRepository()),
      ],
    );
    final settle = tester.pumpAndSettle;
    await settle();
    final catalog = find.byType(CatalogScreen);
    final initialState = tester.state(catalog);
    final marker = find.byType(MediaCardBookmark);
    expect(marker, findsNothing);
    expect(requests, [1]);
    favoriteOnSite = true;
    await tester.tap(find.byKey(const ValueKey('catalog-tab-true')));
    await settle();
    await tester.tap(find.byKey(const ValueKey('catalog-tab-false')));
    await settle();
    expect(tester.state(catalog), same(initialState));
    expect(requests, [1, 1]);
    expect(marker, findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a late home response cannot replace a newly selected favorites section', (tester) async {
    final pending = Completer<Result<AnimePage, Failure>>();
    final favorites = FakeFavoritesRepository()..ids.add(20);
    await pumpTvApp(
      tester,
      HomeScreen(onAnimeTap: (_) => fail('Unexpected details')),
      wrapInScaffold: false,
      overrides: [
        authAccessProvider.overrideWithValue(const AuthenticatedAccess('test')),
        favoritesAccountProvider.overrideWithValue('test'),
        catalogRepositoryProvider.overrideWithValue(FakeCatalogScreenRepository(load: (_) => pending.future)),
        favoritesRepositoryProvider.overrideWithValue(favorites),
      ],
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('catalog-tab-true')));
    await tester.pumpAndSettle();
    pending.complete(await const FakeCatalogScreenRepository().getPage(1));
    await tester.pumpAndSettle();
    expect(tester.widget<AnimeCard>(find.byType(AnimeCard)).anime.id, 20);
    expect(FocusManager.instance.primaryFocus?.context?.findAncestorWidgetOfExactType<AnimeCard>()?.anime.id, 20);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Left stays in the poster rail until its first card, then opens the active menu', (tester) async {
    await pumpTvApp(
      tester,
      HomeScreen(onAnimeTap: (_) => fail('Unexpected details')),
      wrapInScaffold: false,
      overrides: [
        authAccessProvider.overrideWithValue(const AuthenticatedAccess('test')),
        favoritesAccountProvider.overrideWithValue('test'),
        catalogRepositoryProvider.overrideWithValue(const FakeCatalogScreenRepository()),
        favoritesRepositoryProvider.overrideWithValue(FakeFavoritesRepository()),
      ],
    );
    await tester.pumpAndSettle();
    int? focusedAnimeId() =>
        FocusManager.instance.primaryFocus?.context?.findAncestorWidgetOfExactType<AnimeCard>()?.anime.id;
    final rail = find.byType(CatalogNavigationRail);

    expect(focusedAnimeId(), 1);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(focusedAnimeId(), 3);
    expect(tester.widget<CatalogNavigationRail>(rail).expanded, isFalse);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(focusedAnimeId(), 2);
    expect(tester.widget<CatalogNavigationRail>(rail).expanded, isFalse);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(focusedAnimeId(), 1);
    expect(tester.widget<CatalogNavigationRail>(rail).expanded, isFalse);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    expect(focusedControlLabel(tester), 'Главная');
    expect(tester.widget<CatalogNavigationRail>(rail).expanded, isTrue);
    expect(tester.takeException(), isNull);
  });
}
