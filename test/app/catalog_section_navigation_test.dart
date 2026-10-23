// Assertions observe identities and focus again after each section transition.

import 'dart:async';

import 'package:anistar_tv/packages/features/auth/auth_providers.dart';
import 'package:anistar_tv/packages/features/catalog/catalog_providers.dart';
import 'package:anistar_tv/packages/features/catalog/domain/models/anime_page.dart';
import 'package:anistar_tv/packages/features/catalog/domain/models/anime_summary.dart';
import 'package:anistar_tv/packages/features/catalog/presentation/screens/catalog_screen.dart';
import 'package:anistar_tv/packages/features/catalog/presentation/widgets/anime_card.dart';
import 'package:anistar_tv/packages/features/catalog/presentation/widgets/catalog_navigation_rail.dart';
import 'package:anistar_tv/packages/features/favorites/favorites_providers.dart';
import 'package:anistar_tv/packages/features/home/presentation/screens/home_screen.dart';
import 'package:core/data.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';

import '../mocks/features/catalog/fake_catalog_screen_repository.dart';
import '../mocks/features/favorites/fake_favorites_repository.dart';
import '../support/test_app.dart';

void main() {
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
          catalogRepositoryProvider.overrideWithValue(const FakeCatalogScreenRepository()),
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
      expect(focusedControlLabel(tester), 'Аниме 20');
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
        catalogRepositoryProvider.overrideWithValue(const FakeCatalogScreenRepository()),
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
    expect(focusedControlLabel(tester), 'Аниме 20');
    expect(tester.takeException(), isNull);
  });

  testWidgets('Left stays in a card row until its first column, then opens the active menu', (tester) async {
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
