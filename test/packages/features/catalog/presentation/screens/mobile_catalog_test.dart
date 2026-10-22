import 'dart:async';

import 'package:anistar_tv/packages/features/auth/auth_providers.dart';
import 'package:anistar_tv/packages/features/catalog/catalog_providers.dart';
import 'package:anistar_tv/packages/features/catalog/domain/models/anime_page.dart';
import 'package:anistar_tv/packages/features/catalog/domain/models/anime_summary.dart';
import 'package:anistar_tv/packages/features/catalog/domain/models/catalog_filter.dart';
import 'package:anistar_tv/packages/features/catalog/presentation/mobile/mobile_anime_card.dart';
import 'package:anistar_tv/packages/features/catalog/presentation/screens/catalog_screen.dart';
import 'package:anistar_tv/packages/features/favorites/favorites_providers.dart';
import 'package:anistar_tv/packages/features/home/presentation/screens/home_screen.dart';
import 'package:core/data.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../../mocks/features/catalog/fake_catalog_browse_repository.dart';
import '../../../../../mocks/features/catalog/fake_catalog_screen_repository.dart';
import '../../../../../mocks/features/favorites/fake_favorites_repository.dart';
import '../../../../../support/test_app.dart';

FakeCatalogScreenRepository longMobileCatalog() => FakeCatalogScreenRepository(
  load: (_) async => Result.success(
    AnimePage(
      items: List.generate(
        50,
        (i) => AnimeSummary(id: i + 1, slug: '${i + 1}-anime', title: 'Аниме ${i + 1}', posterUri: Uri()),
      ),
      page: 1,
      hasNext: false,
    ),
  ),
);

// Route navigation is deliberately outside these layout tests.
// ignore: no-empty-block
void ignoreAnimeTap(AnimeSummary _) {
  // These layout/scroll tests do not navigate to a separate anime route.
}

// Authentication is covered separately; the golden only needs the action present.
// ignore: no-empty-block
void ignoreSignOut() {
  // The account action is present for its golden; authentication is tested separately.
}

ScrollController mobileCatalogController(WidgetTester tester, Finder scroll) =>
    tester.widget<CustomScrollView>(scroll).controller ?? (throw TestFailure('Catalog must own a scroll controller'));

void main() {
  final catalogScroll = find.byType(CustomScrollView);
  final navigationBar = find.byType(NavigationBar);
  final account = find.byKey(const ValueKey('mobile-account'));
  final visibleAccount = account.hitTestable();
  final bottomSheet = find.byType(BottomSheet);
  final destinations = find.byType(NavigationDestination);
  final homeDestination = destinations.at(0);
  final favoritesDestination = destinations.at(2);
  final genresDestination = destinations.at(3);
  final app = find.byType(MaterialApp);
  final firstCardActions = find.byKey(const ValueKey('anime-actions-1'));
  final longCatalogOverride = catalogRepositoryProvider.overrideWithValue(longMobileCatalog());

  // Pumps must execute after each gesture; geometry must be sampled again after layout.
  // These stateful operations cannot be replaced with a cached return value.
  testWidgets('mobile header releases viewport on scroll down and returns on scroll up', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpMobileApp(
      tester,
      const HomeScreen(onAnimeTap: ignoreAnimeTap, onSignOut: ignoreSignOut),
      wrapInScaffold: false,
      overrides: [
        authAccessProvider.overrideWithValue(const AuthenticatedAccess('test')),
        favoritesAccountProvider.overrideWithValue('test'),
        longCatalogOverride,
      ],
    );
    // ignore: prefer-moving-to-variable
    await tester.pumpAndSettle();
    final scroll = catalogScroll;
    // ignore: prefer-moving-to-variable
    final initialTop = tester.getTopLeft(scroll).dy;
    // ignore: prefer-moving-to-variable
    final navigationTop = tester.getTopLeft(navigationBar).dy;
    await tester.drag(scroll, const Offset(0, -400));
    // ignore: prefer-moving-to-variable
    await tester.pumpAndSettle();
    // ignore: prefer-moving-to-variable
    expect(tester.getTopLeft(scroll).dy, initialTop - kToolbarHeight);
    expect(visibleAccount, findsNothing);
    expect(find.bySemanticsLabel('Аккаунт'), findsNothing);
    // ignore: prefer-moving-to-variable
    expect(tester.getTopLeft(navigationBar).dy, navigationTop);
    // Reversal reveals the header while keeping the user's catalog position.
    await tester.drag(scroll, const Offset(0, 80));
    // ignore: prefer-moving-to-variable
    await tester.pumpAndSettle();
    // ignore: prefer-moving-to-variable
    expect(tester.getTopLeft(scroll).dy, initialTop);
    expect(visibleAccount, findsOneWidget);
    expect(mobileCatalogController(tester, scroll).offset, greaterThan(0));
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('short mobile catalog keeps its header during overscroll', (tester) async {
    await pumpMobileApp(
      tester,
      const HomeScreen(onAnimeTap: ignoreAnimeTap),
      wrapInScaffold: false,
      overrides: [
        authAccessProvider.overrideWithValue(const AuthenticatedAccess('test')),
        favoritesAccountProvider.overrideWithValue('test'),
        catalogRepositoryProvider.overrideWithValue(
          FakeCatalogScreenRepository(
            load: (_) async => Result.success(
              AnimePage(
                items: [AnimeSummary(id: 1, slug: '1-anime', title: 'Аниме', posterUri: Uri())],
                page: 1,
                hasNext: false,
              ),
            ),
          ),
        ),
      ],
    );
    // ignore: prefer-moving-to-variable
    await tester.pumpAndSettle();
    await tester.drag(catalogScroll, const Offset(0, -200));
    // ignore: prefer-moving-to-variable
    await tester.pumpAndSettle();
    expect(visibleAccount, findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('last mobile row clears translucent navigation and header remains collapsed at list end', (tester) async {
    await pumpMobileApp(
      tester,
      const HomeScreen(onAnimeTap: ignoreAnimeTap),
      wrapInScaffold: false,
      overrides: [
        authAccessProvider.overrideWithValue(const AuthenticatedAccess('test')),
        favoritesAccountProvider.overrideWithValue('test'),
        longCatalogOverride,
      ],
    );
    // ignore: prefer-moving-to-variable
    await tester.pumpAndSettle();
    final scroll = catalogScroll;
    await tester.drag(scroll, const Offset(0, -400));
    // ignore: prefer-moving-to-variable
    await tester.pumpAndSettle();
    final controller = mobileCatalogController(tester, scroll);
    controller.jumpTo(controller.position.maxScrollExtent);
    // ignore: prefer-moving-to-variable
    await tester.pumpAndSettle();
    final navigationTop = tester.getTopLeft(navigationBar).dy;
    final lastCard = find.byKey(const ValueKey(50));
    expect(tester.getBottomLeft(lastCard).dy, lessThanOrEqualTo(navigationTop));
    expect(find.byKey(const ValueKey('anime-actions-50')).hitTestable(), findsOneWidget);
    expect(visibleAccount, findsNothing);
    final lastOffset = controller.offset;
    await tester.drag(scroll, const Offset(0, -100));
    // ignore: prefer-moving-to-variable
    await tester.pumpAndSettle();
    expect(controller.offset, lastOffset);
    // Recheck after end overscroll to catch viewport/header oscillation.
    // ignore: avoid-duplicate-test-assertions
    expect(visibleAccount, findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('accessible navigation keeps header targets stable while scrolling', (tester) async {
    await pumpMobileApp(
      tester,
      Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(accessibleNavigation: true),
          child: const HomeScreen(onAnimeTap: ignoreAnimeTap),
        ),
      ),
      wrapInScaffold: false,
      overrides: [
        authAccessProvider.overrideWithValue(const AuthenticatedAccess('test')),
        favoritesAccountProvider.overrideWithValue('test'),
        longCatalogOverride,
      ],
    );
    // ignore: prefer-moving-to-variable
    await tester.pumpAndSettle();
    await tester.drag(catalogScroll, const Offset(0, -400));
    // ignore: prefer-moving-to-variable
    await tester.pumpAndSettle();
    expect(visibleAccount, findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion keeps header visible at doubled landscape text', (tester) async {
    await pumpMobileApp(
      tester,
      const HomeScreen(onAnimeTap: ignoreAnimeTap),
      wrapInScaffold: false,
      size: const Size(844, 390),
      textScale: 2,
      disableAnimations: true,
      overrides: [
        authAccessProvider.overrideWithValue(const AuthenticatedAccess('test')),
        favoritesAccountProvider.overrideWithValue('test'),
        longCatalogOverride,
      ],
    );
    await tester.pumpAndSettle();
    final scroll = catalogScroll;
    // ignore: prefer-moving-to-variable
    final top = tester.getTopLeft(scroll).dy;
    await tester.drag(scroll, const Offset(0, -100));
    await tester.pump();
    // ignore: prefer-moving-to-variable
    expect(tester.getTopLeft(scroll).dy, top);
    expect(visibleAccount, findsOneWidget);
    expect(navigationBar.hitTestable(), findsOneWidget);
    await tester.drag(scroll, const Offset(0, 30));
    await tester.pump();
    expect(visibleAccount, findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('unmount during a pending pull refresh cancels completion without an uncaught error', (tester) async {
    final pending = Completer<Result<AnimePage, Failure>>();
    var requests = 0;
    await pumpMobileApp(
      tester,
      const CatalogScreen(onAnimeTap: ignoreAnimeTap),
      wrapInScaffold: false,
      overrides: [
        authAccessProvider.overrideWithValue(const AuthenticatedAccess('test')),
        favoritesAccountProvider.overrideWithValue('test'),
        catalogRepositoryProvider.overrideWithValue(
          FakeCatalogScreenRepository(
            load: (page) {
              requests++;

              return requests == 1 ? const FakeCatalogScreenRepository().getPage(page) : pending.future;
            },
          ),
        ),
      ],
    );
    // ignore: prefer-moving-to-variable
    await tester.pumpAndSettle();
    final refresh = tester.widget<RefreshIndicator>(find.byType(RefreshIndicator)).onRefresh();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(requests, 2);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await refresh;
    pending.complete(Result.success(AnimePage(items: [], page: 1, hasNext: false)));
    // ignore: prefer-moving-to-variable
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('genres are a root touch destination and account actions stay discoverable', (tester) async {
    const genre = CatalogFilter(label: 'Повседневность', path: '/everyday/');
    CatalogFilter? selected;
    var signedOut = false;
    await pumpMobileApp(
      tester,
      HomeScreen(
        accountName: 'overman',
        onAnimeTap: ignoreAnimeTap,
        onGenreSelected: (item) => selected = item,
        onSignOut: () => signedOut = true,
      ),
      wrapInScaffold: false,
      overrides: [
        authAccessProvider.overrideWithValue(const AuthenticatedAccess('test')),
        favoritesAccountProvider.overrideWithValue('test'),
        catalogRepositoryProvider.overrideWithValue(const FakeCatalogScreenRepository()),
        catalogBrowseRepositoryProvider.overrideWithValue(
          FakeCatalogBrowseRepository(genres: () async => const Result.success([genre])),
        ),
      ],
    );
    // ignore: prefer-moving-to-variable
    await tester.pumpAndSettle();
    await tester.tap(genresDestination);
    // ignore: prefer-moving-to-variable
    await tester.pumpAndSettle();
    await tester.tap(find.text('Повседневность'));
    expect(selected, genre);
    await tester.tap(account);
    // ignore: prefer-moving-to-variable
    await tester.pumpAndSettle();
    expect(find.text('overman'), findsOneWidget);
    await tester.tap(find.text('Выйти из аккаунта'));
    // ignore: prefer-moving-to-variable
    await tester.pumpAndSettle();
    expect(signedOut, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mobile tabs retain catalog scroll while section return refreshes site state', (tester) async {
    final requests = <int>[];
    final favorites = FakeFavoritesRepository()..ids.add(101);
    await pumpMobileApp(
      tester,
      const HomeScreen(onAnimeTap: ignoreAnimeTap),
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
                  items: List.generate(
                    50,
                    (i) => AnimeSummary(id: i + 1, slug: '${i + 1}-anime', title: 'Аниме ${i + 1}', posterUri: Uri()),
                  ),
                  page: 1,
                  hasNext: false,
                ),
              );
            },
          ),
        ),
        favoritesRepositoryProvider.overrideWithValue(favorites),
      ],
    );
    // ignore: prefer-moving-to-variable
    await tester.pumpAndSettle();
    await tester.drag(catalogScroll, const Offset(0, -600));
    // ignore: prefer-moving-to-variable
    await tester.pumpAndSettle();
    final controller = mobileCatalogController(tester, catalogScroll);
    final offset = controller.offset;
    expect(offset, greaterThan(0));
    expect(visibleAccount, findsNothing);
    await tester.tap(favoritesDestination);
    // ignore: prefer-moving-to-variable
    await tester.pumpAndSettle();
    expect(visibleAccount, findsOneWidget);
    expect(find.text('Аниме 101'), findsOneWidget);
    await tester.binding.handlePopRoute();
    // ignore: prefer-moving-to-variable
    await tester.pumpAndSettle();
    expect(tester.widget<NavigationBar>(navigationBar).selectedIndex, 0);
    expect(controller.offset, offset);
    // System Back must also reveal the header on the restored destination.
    // ignore: avoid-duplicate-test-assertions
    expect(visibleAccount, findsOneWidget);
    expect(requests, [1, 1]);
    expect(favorites.pages, [1]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('two mobile catalog pages keep their scroll and fresh favorite flags after section return', (
    tester,
  ) async {
    var favoriteOnSite = false;
    final requests = <int>[];
    await pumpMobileApp(
      tester,
      const HomeScreen(onAnimeTap: ignoreAnimeTap),
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
                  items: List.generate(12, (index) {
                    final id = (page - 1) * 12 + index + 1;

                    return AnimeSummary(id: id, slug: '$id-anime', title: 'Аниме $id', isFavorite: favoriteOnSite);
                  }),
                  page: page,
                  hasNext: page == 1,
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
    final controller = mobileCatalogController(tester, catalogScroll);
    controller.jumpTo(controller.position.maxScrollExtent);
    await settle();
    expect(requests, [1, 2]);
    final offset = controller.offset;
    final readMetrics = controller.position.copyWith;
    final initialMetrics = readMetrics();
    final contentExtent = initialMetrics.maxScrollExtent + initialMetrics.viewportDimension;
    expect(offset, greaterThan(0));
    favoriteOnSite = true;
    await tester.tap(favoritesDestination);
    await settle();
    await tester.binding.handlePopRoute();
    await settle();
    expect(controller.offset, offset);
    final returnedMetrics = readMetrics();
    expect(returnedMetrics.maxScrollExtent + returnedMetrics.viewportDimension, contentExtent);
    expect(requests, [1, 2, 1, 2]);
    final secondPage = tester.widget<MobileAnimeCard>(find.byKey(const ValueKey(13)));
    expect(secondPage.anime.isFavorite, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('visible card action opens bottom panel and applies confirmed favorite', (tester) async {
    final favorites = FakeFavoritesRepository();
    int? opened;
    await pumpMobileApp(
      tester,
      CatalogScreen(onAnimeTap: (anime) => opened = anime.id),
      wrapInScaffold: false,
      overrides: [
        authAccessProvider.overrideWithValue(const AuthenticatedAccess('test')),
        favoritesAccountProvider.overrideWithValue('test'),
        catalogRepositoryProvider.overrideWithValue(const FakeCatalogScreenRepository()),
        favoritesRepositoryProvider.overrideWithValue(favorites),
      ],
    );
    // ignore: prefer-moving-to-variable
    await tester.pumpAndSettle();
    await tester.tap(firstCardActions);
    // ignore: prefer-moving-to-variable
    await tester.pumpAndSettle();
    expect(bottomSheet, findsOneWidget);
    await tester.tap(find.text('Добавить в избранное'));
    // ignore: prefer-moving-to-variable
    await tester.pumpAndSettle();
    expect(favorites.ids, contains(1));
    expect(favorites.writes, [true]);
    expect(bottomSheet, findsNothing);
    expect(opened, isNull);
    await tester.tap(find.byType(MobileAnimeCard).first);
    expect(opened, 1);
    expect(tester.takeException(), isNull);
  });

  for (final size in [const Size(320, 640), const Size(390, 844), const Size(844, 390)]) {
    testWidgets('mobile catalog handles $size with doubled text', (tester) async {
      await pumpMobileApp(
        tester,
        const CatalogScreen(onAnimeTap: ignoreAnimeTap),
        size: size,
        textScale: 2,
        wrapInScaffold: false,
        overrides: [
          authAccessProvider.overrideWithValue(const AuthenticatedAccess('test')),
          favoritesAccountProvider.overrideWithValue('test'),
          catalogRepositoryProvider.overrideWithValue(const FakeCatalogScreenRepository()),
        ],
      );
      await tester.pumpAndSettle();
      expect(find.byType(MobileAnimeCard), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('mobile main, actions, empty favorites and genres goldens', (tester) async {
    await pumpMobileApp(
      tester,
      const HomeScreen(accountName: 'overman', onAnimeTap: ignoreAnimeTap, onSignOut: ignoreSignOut),
      wrapInScaffold: false,
      disableAnimations: true,
      overrides: [
        authAccessProvider.overrideWithValue(const AuthenticatedAccess('test')),
        favoritesAccountProvider.overrideWithValue('test'),
        catalogRepositoryProvider.overrideWithValue(const FakeCatalogScreenRepository()),
        favoritesRepositoryProvider.overrideWithValue(FakeFavoritesRepository()),
        catalogBrowseRepositoryProvider.overrideWithValue(FakeCatalogBrowseRepository()),
      ],
    );
    // ignore: prefer-moving-to-variable
    await tester.pumpAndSettle();
    await expectLater(app, matchesGoldenFile('goldens/mobile_home_390.png'));
    await tester.tap(firstCardActions);
    // ignore: prefer-moving-to-variable
    await tester.pumpAndSettle();
    await expectLater(app, matchesGoldenFile('goldens/mobile_actions_390.png'));
    await tester.tap(find.byTooltip('Закрыть').last);
    // ignore: prefer-moving-to-variable
    await tester.pumpAndSettle();
    await tester.tap(favoritesDestination);
    // ignore: prefer-moving-to-variable
    await tester.pumpAndSettle();
    await expectLater(app, matchesGoldenFile('goldens/mobile_favorites_empty_390.png'));
    await tester.tap(genresDestination);
    // ignore: prefer-moving-to-variable
    await tester.pumpAndSettle();
    await expectLater(app, matchesGoldenFile('goldens/mobile_genres_390.png'));
    await tester.tap(homeDestination);
    // ignore: prefer-moving-to-variable
    await tester.pumpAndSettle();
    await tester.drag(catalogScroll, const Offset(0, -250));
    // ignore: prefer-moving-to-variable
    await tester.pumpAndSettle();
    await expectLater(app, matchesGoldenFile('goldens/mobile_home_scrolled_390.png'));
  }, tags: ['golden']);
}
