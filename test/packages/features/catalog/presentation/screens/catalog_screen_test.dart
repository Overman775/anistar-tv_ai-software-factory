import 'package:anistar_tv/packages/features/catalog/catalog_providers.dart';
import 'package:anistar_tv/packages/features/catalog/domain/models/anime_page.dart';
import 'package:anistar_tv/packages/features/catalog/domain/models/anime_summary.dart';
import 'package:anistar_tv/packages/features/catalog/presentation/screens/catalog_screen.dart';
import 'package:anistar_tv/packages/features/catalog/presentation/widgets/anime_card.dart';
import 'package:anistar_tv/packages/features/catalog/presentation/widgets/catalog_skeleton.dart';
import 'package:anistar_tv/packages/features/catalog/presentation/widgets/catalog_tail.dart';
import 'package:anistar_tv/packages/features/favorites/favorites_providers.dart';
import 'package:anistar_tv/packages/features/favorites/presentation/favorite_actions_sheet.dart';
import 'package:anistar_tv/packages/features/home/presentation/screens/home_screen.dart';
import 'package:core/data.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';

import '../../../../../mocks/features/catalog/fake_catalog_screen_repository.dart';
import '../../../../../mocks/features/favorites/fake_favorites_repository.dart';
import '../../../../../support/test_app.dart';

// Focus is mutable: each assertion reads the result of the preceding key event.
// ignore_for_file: prefer-moving-to-variable

void main() {
  testWidgets('a thousand catalog entries stay virtualized and the last row remains operable', (tester) async {
    final items = List.generate(
      1000,
      (index) =>
          AnimeSummary(id: index + 1, slug: '${index + 1}-anime', title: 'Аниме ${index + 1}・🎬', posterUri: Uri()),
    );
    final requests = <int>[];
    int? opened;
    final repository = FakeCatalogScreenRepository(
      load: (page) async {
        requests.add(page);

        return Result.success(AnimePage(items: items, page: 1, hasNext: false));
      },
    );
    await pumpTvApp(
      tester,
      CatalogScreen(onAnimeTap: (anime) => opened = anime.id),
      size: wideTvSize,
      wrapInScaffold: false,
      overrides: [catalogRepositoryProvider.overrideWithValue(repository)],
    );
    await tester.pumpAndSettle();
    expect(find.byType(AnimeCard).evaluate().length, lessThan(50));
    final scroll = tester.widget<CustomScrollView>(find.byType(CustomScrollView)).controller;
    scroll?.jumpTo(scroll.position.maxScrollExtent);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey(1000)));
    await tester.pumpAndSettle();
    expect(opened, 1000);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    expect(opened, 999);
    expect(requests, [1]);
    expect(tester.takeException(), isNull);
  });
  testWidgets('rail expands from any first-column card and returns to the same card', (tester) async {
    await pumpTvApp(
      tester,
      CatalogScreen(
        onAnimeTap: (_) => fail('Unexpected activation'),
        onTabSelected: (_) => fail('Only focus should change'),
        onSignOut: () => fail('Unexpected logout'),
        onOpenLogs: () => fail('Unexpected logs'),
      ),
      wrapInScaffold: false,
      overrides: [catalogRepositoryProvider.overrideWithValue(const FakeCatalogScreenRepository())],
    );
    await tester.pumpAndSettle();
    final rail = find.byKey(const ValueKey('catalog-navigation-rail'));
    expect(tester.getSize(rail).width, 88);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    final card = FocusManager.instance.primaryFocus;
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    expect(tester.getSize(rail).width, inExclusiveRange(88, 264));
    await tester.pumpAndSettle();
    expect(tester.getSize(rail).width, 264);
    final labels = <String?>[FocusManager.instance.primaryFocus?.debugLabel];
    for (var i = 0; i < 3; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      labels.add(FocusManager.instance.primaryFocus?.debugLabel);
    }
    expect(labels, ['Главная', 'Избранное', 'Выйти из аккаунта', 'Открыть логи']);
    expect(find.byKey(const ValueKey('catalog-refresh')), findsNothing);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'Открыть логи');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(FocusManager.instance.primaryFocus, same(card));
    // Check the final collapsed width after the return transition.
    // ignore: avoid-duplicate-test-assertions
    expect(tester.getSize(rail).width, 88);
    expect(tester.takeException(), isNull);
  });

  testWidgets('release rail skips logs and Back collapses it without leaving the catalog', (tester) async {
    await pumpTvApp(
      tester,
      CatalogScreen(
        onAnimeTap: (_) => fail('Unexpected activation'),
        onTabSelected: (_) => fail('Unexpected navigation'),
        onSignOut: () => fail('Unexpected logout'),
      ),
      wrapInScaffold: false,
      overrides: [catalogRepositoryProvider.overrideWithValue(const FakeCatalogScreenRepository())],
    );
    await tester.pumpAndSettle();
    final card = FocusManager.instance.primaryFocus;
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    for (var i = 0; i < 4; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
    }
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'Выйти из аккаунта');
    expect(find.byKey(const ValueKey('catalog-logs')), findsNothing);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(FocusManager.instance.primaryFocus, same(card));
    expect(find.byType(CatalogScreen), findsOneWidget);
  });

  testWidgets('empty favorites can focus their content action and return home', (tester) async {
    await pumpTvApp(
      tester,
      HomeScreen(onAnimeTap: (_) => fail('Unexpected activation')),
      wrapInScaffold: false,
      overrides: [
        catalogRepositoryProvider.overrideWithValue(const FakeCatalogScreenRepository()),
        favoritesRepositoryProvider.overrideWithValue(FakeFavoritesRepository()),
      ],
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('catalog-tab-true')));
    await tester.pumpAndSettle();
    expect(find.text('Избранное пусто'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(find.byType(AnimeCard), findsWidgets);
  });

  testWidgets('long OK slides actions from the right and Left closes it restoring the card', (tester) async {
    final favorites = FakeFavoritesRepository();
    await pumpTvApp(
      tester,
      HomeScreen(onAnimeTap: (_) => fail('Long OK must not open details')),
      wrapInScaffold: false,
      overrides: [
        catalogRepositoryProvider.overrideWithValue(const FakeCatalogScreenRepository()),
        favoritesRepositoryProvider.overrideWithValue(favorites),
      ],
    );
    await tester.pumpAndSettle();
    final card = FocusManager.instance.primaryFocus;
    await tester.sendKeyDownEvent(LogicalKeyboardKey.select);
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.select);

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    final sheet = find.byType(TvSideSheet);
    final surface = find.descendant(of: sheet, matching: find.byType(Material)).first;
    expect(tester.getTopLeft(surface).dx, greaterThan(520));
    await tester.pumpAndSettle();
    expect(tester.getRect(surface).right, 960);
    expect(tester.getRect(surface).left, 520);
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.select);
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.select);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(favorites.writes, isEmpty);
    for (final key in [LogicalKeyboardKey.arrowRight, LogicalKeyboardKey.arrowDown]) {
      await tester.sendKeyEvent(key);
      await tester.pumpAndSettle();
      expect(FocusManager.instance.primaryFocus?.context?.findAncestorWidgetOfExactType<TvSideSheet>(), isNotNull);
    }
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    expect(FocusManager.instance.primaryFocus, same(card));
    expect(favorites.writes, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('removing the last favorite from its sheet returns focus to navigation', (tester) async {
    final favorites = FakeFavoritesRepository()..ids.add(1);
    await pumpTvApp(
      tester,
      HomeScreen(onAnimeTap: (_) => fail('Unexpected activation')),
      wrapInScaffold: false,
      overrides: [
        catalogRepositoryProvider.overrideWithValue(const FakeCatalogScreenRepository()),
        favoritesRepositoryProvider.overrideWithValue(favorites),
      ],
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('catalog-tab-true')));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.select);
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.select);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(find.text('Избранное пусто'), findsOneWidget);
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'Избранное');
    expect(find.byType(FavoriteActionsSheet), findsNothing);
    expect(favorites.ids, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion expands the rail immediately without moving the grid', (tester) async {
    await pumpTvApp(
      tester,
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: HomeScreen(onAnimeTap: (_) => fail('Unexpected activation')),
      ),
      wrapInScaffold: false,
      overrides: [catalogRepositoryProvider.overrideWithValue(const FakeCatalogScreenRepository())],
    );
    await tester.pumpAndSettle();
    final card = find.byType(AnimeCard).first;
    final before = tester.getRect(card);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    await tester.pump();
    expect(tester.getSize(find.byKey(const ValueKey('catalog-navigation-rail'))).width, 264);
    expect(tester.getRect(card), before);
    expect(tester.takeException(), isNull);
  });

  testWidgets('catalog errors focus retry and allow a round trip through the rail', (tester) async {
    var requests = 0;
    await pumpTvApp(
      tester,
      HomeScreen(onAnimeTap: (_) => fail('Unexpected activation')),
      wrapInScaffold: false,
      overrides: [
        catalogRepositoryProvider.overrideWithValue(
          FakeCatalogScreenRepository(
            load: (_) async {
              requests++;

              return requests == 1
                  ? const Result.failure(UnknownFailure())
                  : const FakeCatalogScreenRepository().getPage(1);
            },
          ),
        ),
      ],
    );
    await tester.pumpAndSettle();
    final retry = FocusManager.instance.primaryFocus;
    expect(retry?.context?.findAncestorWidgetOfExactType<FilledButton>(), isNotNull);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'Главная');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(FocusManager.instance.primaryFocus, same(retry));
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(requests, 2);
    expect(find.byType(AnimeCard), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('portrait catalog keeps two readable columns and matches its loading layout', (tester) async {
    const phoneSize = Size(412, 915);
    final gridFinder = find.byType(SliverGrid);
    await pumpTvApp(tester, const CatalogSkeleton(), size: phoneSize);
    final loadingGrid = tester.widget<SliverGrid>(gridFinder);
    expect((loadingGrid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount).crossAxisCount, 2);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await pumpTvApp(
      tester,
      CatalogScreen(
        onAnimeTap: (_) => fail('Unexpected anime activation'),
        onTabSelected: (_) => fail('Unexpected tab activation'),
        onSignOut: () => fail('Unexpected logout'),
        onOpenLogs: () => fail('Unexpected logs'),
      ),
      size: phoneSize,
      wrapInScaffold: false,
      overrides: [catalogRepositoryProvider.overrideWithValue(const FakeCatalogScreenRepository())],
    );
    await tester.pumpAndSettle();
    final grid = tester.widget<SliverGrid>(gridFinder);
    expect((grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount).crossAxisCount, 2);
    // Check the loaded screen separately from the skeleton above.
    // ignore: avoid-duplicate-test-assertions
    expect(tester.takeException(), isNull);
  });

  testWidgets('pagination failure waits for manual retry while focus and scrolling continue', (tester) async {
    final requests = <int>[];
    final pumpAndSettle = tester.pumpAndSettle;
    final initial = (await const FakeCatalogScreenRepository().getPage(1))
        .when(failure: (failure) => throw failure, success: (page) => page);
    final repository = FakeCatalogScreenRepository(
      load: (page) async {
        requests.add(page);

        return page == 1
            ? Result.success(AnimePage(items: initial.items, page: 1, hasNext: true))
            : const Result.failure(UnknownFailure());
      },
    );
    await pumpTvApp(
      tester,
      CatalogScreen(onAnimeTap: (anime) => expect(anime.id, isPositive)),
      wrapInScaffold: false,
      overrides: [catalogRepositoryProvider.overrideWithValue(repository)],
    );
    await pumpAndSettle();
    for (var i = 0; i < 4; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await pumpAndSettle();
    }
    expect(requests, [1, 2]);
    final scroll = tester.widget<CustomScrollView>(find.byType(CustomScrollView)).controller;
    if (scroll == null) {
      fail('Catalog must own its scroll controller.');
    }
    scroll.jumpTo(scroll.position.maxScrollExtent);
    await pumpAndSettle();
    // The second assertion verifies that scrolling did not retry the failed page.
    // ignore: avoid-duplicate-test-assertions
    expect(requests, [1, 2]);
    await tester.tap(find.byType(CatalogTail));
    await pumpAndSettle();
    expect(requests, [1, 2, 2]);
  });

  testWidgets('moves focus across a 1280x720 TV grid and activates with OK', (tester) async {
    int? openedAnimeId;
    await pumpTvApp(
      tester,
      CatalogScreen(onAnimeTap: (anime) => openedAnimeId = anime.id),
      size: wideTvSize,
      wrapInScaffold: false,
      overrides: [catalogRepositoryProvider.overrideWithValue(const FakeCatalogScreenRepository())],
    );
    final pumpAndSettle = tester.pumpAndSettle;
    final sendKeyEvent = tester.sendKeyEvent;
    await pumpAndSettle();
    expect(find.byType(AnimeCard), findsAtLeastNWidgets(5));
    expect(tester.takeException(), isNull);
    await sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump(AppMotion.fast);
    await sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await pumpAndSettle();
    await sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await pumpAndSettle();
    await sendKeyEvent(LogicalKeyboardKey.select);
    expect(openedAnimeId, 12);
  });

  testWidgets('returning to the first row reveals the whole focused card below the tabs', (tester) async {
    await pumpTvApp(
      tester,
      CatalogScreen(
        onAnimeTap: (_) => fail('Unexpected anime activation'),
        onTabSelected: (_) => fail('Unexpected tab activation'),
      ),
      wrapInScaffold: false,
      overrides: [catalogRepositoryProvider.overrideWithValue(const FakeCatalogScreenRepository())],
    );
    final settle = tester.pumpAndSettle;
    final key = tester.sendKeyEvent;
    await settle();
    await key(LogicalKeyboardKey.arrowDown);
    await settle();
    await key(LogicalKeyboardKey.arrowDown);
    await settle();
    await key(LogicalKeyboardKey.arrowRight);
    await settle();
    await key(LogicalKeyboardKey.arrowUp);
    await settle();
    await key(LogicalKeyboardKey.arrowUp);
    await settle();
    final card = find.descendant(of: find.byKey(const ValueKey(1)), matching: find.byType(AnimatedContainer));
    const bodyTop = 32.0;
    expect(tester.getTopLeft(card).dy, greaterThanOrEqualTo(bodyTop));
    expect(tester.getBottomRight(card).dy, lessThanOrEqualTo(compactTvSize.height));
    expect(tester.widget<CustomScrollView>(find.byType(CustomScrollView)).clipBehavior, Clip.hardEdge);
  });

  testWidgets('switching to empty favorites keeps focus on its tab and allows remote return home', (tester) async {
    await pumpTvApp(
      tester,
      HomeScreen(onAnimeTap: (anime) => expect(anime.id, 1), onSignOut: () => fail('Unexpected logout')),
      size: wideTvSize,
      wrapInScaffold: false,
      overrides: [
        catalogRepositoryProvider.overrideWithValue(const FakeCatalogScreenRepository()),
        favoritesRepositoryProvider.overrideWithValue(FakeFavoritesRepository()),
      ],
    );
    final settle = tester.pumpAndSettle;
    final key = tester.sendKeyEvent;
    await settle();
    await key(LogicalKeyboardKey.arrowLeft);
    await settle();
    await key(LogicalKeyboardKey.arrowDown);
    await key(LogicalKeyboardKey.select);
    await settle();
    Key? focusedTab() => FocusManager.instance.primaryFocus?.context?.findAncestorWidgetOfExactType<TextButton>()?.key;
    expect(find.text('Избранное пусто'), findsOneWidget);
    // Re-read focus after the tab's widget tree has been replaced.
    expect(focusedTab(), const ValueKey('catalog-tab-true'));
    await key(LogicalKeyboardKey.arrowUp);
    await key(LogicalKeyboardKey.select);
    await settle();
    expect(find.text('Каталог'), findsNothing);
    expect(find.textContaining('загружено'), findsNothing);
    expect(find.textContaining('OK —'), findsNothing);
    // Re-read focus after the tab's widget tree has been replaced.
    expect(focusedTab(), const ValueKey('catalog-tab-false'));
    await key(LogicalKeyboardKey.arrowRight);
    await settle();
    await key(LogicalKeyboardKey.select);
  });

  testWidgets('keeps the catalog heading and first row visible at 960x540', (tester) async {
    await pumpTvApp(
      tester,
      CatalogScreen(onAnimeTap: (anime) => expect(anime.id, isPositive)),
      wrapInScaffold: false,
      overrides: [catalogRepositoryProvider.overrideWithValue(const FakeCatalogScreenRepository())],
    );
    await tester.pumpAndSettle();
    expect(find.text('Каталог'), findsNothing);
    expect(find.textContaining('загружено'), findsNothing);
    expect(find.textContaining('OK —'), findsNothing);
    expect(find.byType(AnimeCard), findsAtLeastNWidgets(4));
    expect(tester.takeException(), isNull);
  });
}
