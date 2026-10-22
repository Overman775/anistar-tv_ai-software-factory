import 'package:anistar_tv/app/app_router.dart';
import 'package:anistar_tv/packages/features/anime/anime_providers.dart';
import 'package:anistar_tv/packages/features/anime/presentation/screens/anime_screen.dart';
import 'package:anistar_tv/packages/features/auth/auth_providers.dart';
import 'package:anistar_tv/packages/features/catalog/catalog_providers.dart';
import 'package:anistar_tv/packages/features/catalog/presentation/mobile/mobile_anime_card.dart';
import 'package:anistar_tv/packages/features/catalog/presentation/screens/catalog_screen.dart';
import 'package:anistar_tv/packages/features/catalog/presentation/screens/genres_screen.dart';
import 'package:app_logging/app_logging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';

import '../mocks/features/anime/fake_anime_screen_repository.dart';
import '../mocks/features/auth/fake_auth_repository.dart';
import '../mocks/features/catalog/fake_catalog_browse_repository.dart';
import '../mocks/features/catalog/fake_catalog_screen_repository.dart';
import '../support/test_app.dart';

void main() {
  testWidgets('actual mobile routes retain root tab scroll and chrome without duplicate destinations', (tester) async {
    final auth = FakeAuthRepository();
    addTearDown(auth.close);
    final router = AppRouter(AppLogger.logger);
    addTearDown(router.dispose);
    await pumpMobileApp(
      tester,
      MaterialApp.router(routerConfig: router.router, theme: AppTheme.mobileDarkTheme),
      wrapInScaffold: false,
      disableAnimations: true,
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        catalogRepositoryProvider.overrideWithValue(const FakeCatalogScreenRepository()),
        catalogBrowseRepositoryProvider.overrideWithValue(
          FakeCatalogBrowseRepository(load: (_, page) => const FakeCatalogScreenRepository().getPage(page)),
        ),
        animeRepositoryProvider.overrideWithValue(const FakeAnimeScreenRepository()),
      ],
    );
    final settle = tester.pumpAndSettle;
    final mobileCards = find.byType(MobileAnimeCard);
    final animeScreen = find.byType(AnimeScreen);
    final genresScreen = find.byType(GenresScreen);
    final comedy = find.text('Комедия');
    final navigation = find.byKey(const ValueKey('mobile-navigation'));
    final hitNavigation = navigation.hitTestable();
    final popRoute = tester.binding.handlePopRoute;
    State<StatefulWidget> genreStateNow() => tester.state(genresScreen);
    String routePath() => router.router.state.uri.path;
    await settle();
    final firstCard = mobileCards.first;
    final poster = find.descendant(of: firstCard, matching: find.byType(TvPosterHero));
    final posterRect = tester.getRect(poster);
    final title = tester.widget<MobileAnimeCard>(firstCard).anime.title;
    expect(
      posterRect.contains(tester.getCenter(find.text(title))),
      isTrue,
      reason: 'mobile title belongs over the shared poster surface',
    );
    final contextAction = find.byKey(const ValueKey('anime-actions-1'));
    expect(posterRect.contains(tester.getCenter(contextAction)), isTrue);
    expect(tester.getSize(contextAction).shortestSide, greaterThanOrEqualTo(48));
    final sourceScroll = find.descendant(of: find.byType(CatalogScreen), matching: find.byType(Scrollable)).first;
    await tester.drag(sourceScroll, const Offset(0, -350));
    await settle();
    final sourcePosition = tester.state<ScrollableState>(sourceScroll).position;
    final sourcePixels = sourcePosition.pixels;
    expect(sourcePixels, isPositive);
    final card = mobileCards.hitTestable().first;
    await tester.tap(card);
    await settle();
    expect(animeScreen, findsOneWidget);
    expect(hitNavigation, findsOneWidget);
    expect(find.byKey(const ValueKey('mobile-account')).hitTestable(), findsOneWidget);
    expect(find.byKey(const ValueKey('mobile-header')).hitTestable(), findsOneWidget);
    await popRoute();
    await settle();
    expect(sourcePosition.pixels, sourcePixels, reason: 'detail return retains the visited home list');
    final genres = find.descendant(of: navigation, matching: find.text('Жанры'));
    await tester.tap(genres);
    await settle();
    final genreState = genreStateNow();
    await tester.tap(comedy);
    await settle();
    final filterRoute = routePath();
    final filterNavigationCount = hitNavigation.evaluate().length;
    expect(filterRoute, '/browse');
    expect(filterNavigationCount, 1, reason: 'filtered route retains exactly one actionable bottom navigation');
    await popRoute();
    await settle();
    expect(genreStateNow(), same(genreState));
    await tester.tap(comedy);
    await settle();
    await tester.tap(find.descendant(of: navigation, matching: find.text('Главная')));
    await settle();
    final returnedRoute = routePath();
    expect(returnedRoute, '/home');
    expect(
      router.router.canPop(),
      isFalse,
      reason: 'choosing a root destination must not leave a duplicate route stack',
    );
    expect(animeScreen, findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
