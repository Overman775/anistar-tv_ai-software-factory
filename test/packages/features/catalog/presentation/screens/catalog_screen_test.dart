import 'package:anistar_tv/packages/features/catalog/catalog_providers.dart';
import 'package:anistar_tv/packages/features/catalog/domain/models/anime_page.dart';
import 'package:anistar_tv/packages/features/catalog/presentation/screens/catalog_screen.dart';
import 'package:anistar_tv/packages/features/catalog/presentation/widgets/anime_card.dart';
import 'package:anistar_tv/packages/features/catalog/presentation/widgets/catalog_tail.dart';
import 'package:core/data.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';

import '../../../../../mocks/features/catalog/fake_catalog_screen_repository.dart';
import '../../../../../support/test_app.dart';

void main() {
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
