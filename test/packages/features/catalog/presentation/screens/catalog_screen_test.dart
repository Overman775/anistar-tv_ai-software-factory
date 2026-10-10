import 'package:anistar_tv/packages/features/catalog/catalog_providers.dart';
import 'package:anistar_tv/packages/features/catalog/domain/models/anime_page.dart';
import 'package:anistar_tv/packages/features/catalog/presentation/screens/catalog_screen.dart';
import 'package:anistar_tv/packages/features/catalog/presentation/widgets/anime_card.dart';
import 'package:anistar_tv/packages/features/catalog/presentation/widgets/catalog_skeleton.dart';
import 'package:anistar_tv/packages/features/catalog/presentation/widgets/catalog_tail.dart';
import 'package:anistar_tv/packages/features/favorites/favorites_providers.dart';
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
  testWidgets('header traverses tabs and every toolbar action and returns to the same card', (tester) async {
    final key = tester.sendKeyEvent;
    final settle = tester.pumpAndSettle;
    String? focusedLabel() => FocusManager.instance.primaryFocus?.debugLabel;
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
    await settle();
    await key(LogicalKeyboardKey.arrowRight);
    await settle();
    final card = FocusManager.instance.primaryFocus;
    await key(LogicalKeyboardKey.arrowUp);
    await settle();
    final labels = <String?>[focusedLabel()];
    for (var step = 0; step < 4; step++) {
      await key(LogicalKeyboardKey.arrowRight);
      await settle();
      labels.add(focusedLabel());
    }
    expect(labels, ['Главная', 'Избранное', 'Выйти из аккаунта', 'Обновить каталог', 'Открыть логи']);
    await key(LogicalKeyboardKey.arrowRight);
    await key(LogicalKeyboardKey.arrowUp);
    await settle();
    expect(focusedLabel(), 'Открыть логи');
    await key(LogicalKeyboardKey.arrowDown);
    await settle();
    expect(FocusManager.instance.primaryFocus, same(card));
  });

  testWidgets('release header skips unavailable log action in both directions', (tester) async {
    final key = tester.sendKeyEvent;
    final settle = tester.pumpAndSettle;
    String? focusedLabel() => FocusManager.instance.primaryFocus?.debugLabel;
    await pumpTvApp(
      tester,
      CatalogScreen(
        onAnimeTap: (_) => fail('Unexpected activation'),
        onTabSelected: (_) => fail('Unexpected tab selection'),
        onSignOut: () => fail('Unexpected logout'),
      ),
      wrapInScaffold: false,
      overrides: [catalogRepositoryProvider.overrideWithValue(const FakeCatalogScreenRepository())],
    );
    await settle();
    await key(LogicalKeyboardKey.arrowUp);
    for (var step = 0; step < 4; step++) {
      await key(LogicalKeyboardKey.arrowRight);
      await settle();
    }
    expect(focusedLabel(), 'Обновить каталог');
    final labels = <String?>[];
    for (var step = 0; step < 3; step++) {
      await key(LogicalKeyboardKey.arrowLeft);
      await settle();
      labels.add(focusedLabel());
    }
    expect(labels, ['Выйти из аккаунта', 'Избранное', 'Главная']);
  });

  testWidgets('empty favorites offer a direct return to the main catalog', (tester) async {
    final settle = tester.pumpAndSettle;
    final key = tester.sendKeyEvent;
    await pumpTvApp(
      tester,
      HomeScreen(onAnimeTap: (_) => fail('Unexpected anime activation'), onSignOut: () => fail('Unexpected logout')),
      wrapInScaffold: false,
      overrides: [
        catalogRepositoryProvider.overrideWithValue(const FakeCatalogScreenRepository()),
        favoritesRepositoryProvider.overrideWithValue(FakeFavoritesRepository()),
      ],
    );
    await settle();
    await tester.tap(find.byKey(const ValueKey('catalog-tab-true')));
    await settle();
    expect(find.text('Избранное пусто'), findsOneWidget);
    await key(LogicalKeyboardKey.arrowDown);
    await settle();
    await key(LogicalKeyboardKey.select);
    await settle();
    expect(find.text('Каталог'), findsOneWidget);
    expect(find.byType(AnimeCard), findsWidgets);
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
    final card = find.descendant(of: find.byKey(const ValueKey(1)), matching: find.byType(Material));
    final bodyTop = tester.getBottomLeft(find.byType(AppBar)).dy;
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
    await key(LogicalKeyboardKey.arrowUp);
    await settle();
    await key(LogicalKeyboardKey.arrowRight);
    await key(LogicalKeyboardKey.select);
    await settle();
    Key? focusedTab() => FocusManager.instance.primaryFocus?.context?.findAncestorWidgetOfExactType<TextButton>()?.key;
    expect(find.text('Избранное пусто'), findsOneWidget);
    // Re-read focus after the tab's widget tree has been replaced.
    expect(focusedTab(), const ValueKey('catalog-tab-true'));
    await key(LogicalKeyboardKey.arrowLeft);
    await key(LogicalKeyboardKey.select);
    await settle();
    expect(find.text('Каталог'), findsOneWidget);
    // Re-read focus after the tab's widget tree has been replaced.
    expect(focusedTab(), const ValueKey('catalog-tab-false'));
    await key(LogicalKeyboardKey.arrowDown);
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
    expect(find.text('Каталог'), findsOneWidget);
    expect(find.byType(AnimeCard), findsAtLeastNWidgets(4));
    expect(tester.takeException(), isNull);
  });
}
