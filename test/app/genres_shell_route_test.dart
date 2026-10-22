import 'dart:async';

import 'package:anistar_tv/app/app_router.dart';
import 'package:anistar_tv/app/app_routes.dart';
import 'package:anistar_tv/packages/features/auth/auth_providers.dart';
import 'package:anistar_tv/packages/features/catalog/catalog_providers.dart';
import 'package:anistar_tv/packages/features/catalog/domain/models/anime_page.dart';
import 'package:anistar_tv/packages/features/catalog/domain/models/anime_summary.dart';
import 'package:anistar_tv/packages/features/catalog/domain/models/catalog_filter.dart';
import 'package:anistar_tv/packages/features/catalog/presentation/screens/catalog_screen.dart';
import 'package:anistar_tv/packages/features/catalog/presentation/screens/genres_screen.dart';
import 'package:anistar_tv/packages/features/catalog/presentation/widgets/catalog_navigation_rail.dart';
import 'package:anistar_tv/packages/features/favorites/favorites_providers.dart';
import 'package:anistar_tv/packages/features/home/presentation/home_destination.dart';
import 'package:anistar_tv/packages/features/home/presentation/screens/home_screen.dart';
import 'package:app_logging/app_logging.dart';
import 'package:core/data.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';

import '../mocks/features/auth/fake_auth_repository.dart';
import '../mocks/features/catalog/fake_catalog_browse_repository.dart';
import '../mocks/features/catalog/fake_catalog_screen_repository.dart';
import '../mocks/features/favorites/fake_favorites_repository.dart';
import '../support/test_app.dart';

void main() {
  for (final outcome in ['ready', 'error', 'empty', 'menu', 'home', 'dispose', 'no entry']) {
    testWidgets('pending inline genres recover actionable focus without stealing it: $outcome', (tester) async {
      final pending = Completer<Result<List<CatalogFilter>, Failure>>();
      final auth = FakeAuthRepository();
      addTearDown(auth.close);
      final router = AppRouter(AppLogger.logger);
      addTearDown(router.dispose);
      await pumpTvApp(
        tester,
        MaterialApp.router(routerConfig: router.router, theme: AppTheme.darkTheme),
        wrapInScaffold: false,
        overrides: [
          authRepositoryProvider.overrideWithValue(auth),
          catalogRepositoryProvider.overrideWithValue(const FakeCatalogScreenRepository()),
          catalogBrowseRepositoryProvider.overrideWithValue(FakeCatalogBrowseRepository(genres: () => pending.future)),
        ],
      );
      final key = tester.sendKeyEvent;
      final pump = tester.pump;
      final settle = tester.pumpAndSettle;
      await settle();
      await key(LogicalKeyboardKey.arrowLeft);
      await key(LogicalKeyboardKey.arrowDown);
      await key(LogicalKeyboardKey.arrowDown);
      await pump();
      final genresFocus = FocusManager.instance.primaryFocus;
      expect(genresFocus?.debugLabel, 'Жанры');
      await key(LogicalKeyboardKey.select);
      await pump();
      expect(find.byType(GenresScreen), findsOneWidget);
      final comedyTile = find.text(comedyFilter.label);
      expect(comedyTile, findsNothing);
      if (outcome != 'no entry') {
        await key(LogicalKeyboardKey.arrowRight);
        await pump();
      }
      final pendingFocus = FocusManager.instance.primaryFocus;
      if (outcome == 'menu' || outcome == 'home') {
        await key(LogicalKeyboardKey.arrowLeft);
        await pump();
        expect(FocusManager.instance.primaryFocus, same(genresFocus));
        if (outcome == 'home') {
          await key(LogicalKeyboardKey.arrowUp);
          await key(LogicalKeyboardKey.arrowUp);
          await key(LogicalKeyboardKey.select);
          await pump();
        }
      } else if (outcome == 'dispose') {
        await tester.pumpWidget(const SizedBox.shrink());
      }
      final retainedFocus = FocusManager.instance.primaryFocus;
      pending.complete(
        outcome == 'error'
            ? const Result.failure(UnknownFailure())
            : Result.success(outcome == 'empty' ? const [] : const [comedyFilter]),
      );
      await settle();
      if (outcome == 'ready') {
        expect(comedyTile, findsOneWidget);
        expect(
          FocusManager.instance.primaryFocus?.debugLabel,
          comedyFilter.label,
          reason:
              'Right entered pending content at ${pendingFocus?.debugLabel}; ready content needs an actionable tile',
        );
        expect(comedyTile.hitTestable(), findsOneWidget);
      } else if (outcome == 'error' || outcome == 'empty') {
        expect(FocusManager.instance.primaryFocus?.debugLabel, 'Повторить загрузку жанров');
      } else if (outcome != 'dispose') {
        expect(FocusManager.instance.primaryFocus, same(retainedFocus));
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  for (final mobile in [false, true]) {
    testWidgets('routed favorites superseded by Home ignore late data and dispose safely mobile=$mobile', (
      tester,
    ) async {
      final pending = Completer<Result<AnimePage, Failure>>();
      final favorites = FakeFavoritesRepository()..load = (_) => pending.future;
      final auth = FakeAuthRepository();
      addTearDown(auth.close);
      final router = AppRouter(AppLogger.logger);
      addTearDown(router.dispose);
      final screen = MaterialApp.router(
        routerConfig: router.router,
        theme: mobile ? AppTheme.mobileDarkTheme : AppTheme.darkTheme,
      );
      final overrides = [
        authRepositoryProvider.overrideWithValue(auth),
        catalogRepositoryProvider.overrideWithValue(const FakeCatalogScreenRepository()),
        favoritesRepositoryProvider.overrideWithValue(favorites),
      ];
      if (mobile) {
        await pumpMobileApp(tester, screen, wrapInScaffold: false, overrides: overrides);
      } else {
        await pumpTvApp(tester, screen, wrapInScaffold: false, overrides: overrides);
      }
      final settle = tester.pumpAndSettle;
      final pump = tester.pump;
      final home = find.byType(HomeScreen);
      await settle();
      final initialContext = tester.element(home);
      const HomeRoute(destination: HomeDestination.favorites).go(initialContext);
      await pump();
      await pump();
      final pendingContext = tester.element(home);
      const HomeRoute().go(pendingContext);
      await pump();
      pending.complete(
        Result.success(
          AnimePage(
            page: 1,
            hasNext: false,
            items: const [AnimeSummary(id: 999, slug: '999-old', title: 'Obsolete favorite', isFavorite: true)],
          ),
        ),
      );
      await settle();
      final catalog = tester.widget<CatalogScreen>(find.byType(CatalogScreen).first);
      expect(catalog.favoritesOnly, isFalse);
      expect(find.text('Obsolete favorite'), findsNothing);
      final disposalContext = tester.element(home);
      const HomeRoute(destination: HomeDestination.favorites).go(disposalContext);
      await tester.pumpWidget(const SizedBox.shrink());
      await pump();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('actual TV route keeps genres in the rail and restores source focus after a filter', (tester) async {
    final auth = FakeAuthRepository();
    addTearDown(auth.close);
    final router = AppRouter(AppLogger.logger);
    addTearDown(router.dispose);
    var genreRequests = 0;
    final browse = FakeCatalogBrowseRepository(
      genres: () async {
        genreRequests++;

        return const Result.success([comedyFilter]);
      },
      load: (_, page) => const FakeCatalogScreenRepository().getPage(page),
    );
    await pumpTvApp(
      tester,
      MaterialApp.router(routerConfig: router.router, theme: AppTheme.darkTheme),
      wrapInScaffold: false,
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        catalogRepositoryProvider.overrideWithValue(const FakeCatalogScreenRepository()),
        catalogBrowseRepositoryProvider.overrideWithValue(browse),
      ],
    );
    final settle = tester.pumpAndSettle;
    final key = tester.sendKeyEvent;
    final popRoute = tester.binding.handlePopRoute;
    final genresScreen = find.byType(GenresScreen);
    String? focusedLabel() => FocusManager.instance.primaryFocus?.debugLabel;
    String routePath() => router.router.state.uri.path;
    await settle();
    final rail = find.byType(CatalogNavigationRail);
    final originalRail = tester.element(rail);
    await key(LogicalKeyboardKey.arrowLeft);
    await key(LogicalKeyboardKey.arrowDown);
    await key(LogicalKeyboardKey.arrowDown);
    await settle();
    final menuFocus = focusedLabel();
    expect(menuFocus, 'Жанры');
    expect(genreRequests, 0, reason: 'focus alone must not load a section');
    await key(LogicalKeyboardKey.select);
    await settle();
    expect(tester.element(rail), same(originalRail));
    final genresRoute = routePath();
    expect(genresRoute, '/home');
    expect(genresScreen, findsOneWidget);
    await key(LogicalKeyboardKey.arrowRight);
    await settle();
    final contentFocus = focusedLabel();
    expect(contentFocus, comedyFilter.label);
    expect(
      tester.getSize(find.byKey(const ValueKey('catalog-navigation-rail'))).width,
      CatalogNavigationRail.collapsedWidth,
    );
    await key(LogicalKeyboardKey.select);
    await settle();
    final filteredRoute = routePath();
    expect(filteredRoute, '/browse');
    await popRoute();
    await settle();
    final restoredFocus = focusedLabel();
    expect(restoredFocus, comedyFilter.label, reason: 'filter return restores the source object');
    await popRoute();
    await settle();
    expect(genresScreen, findsNothing);
    expect(rail, findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
