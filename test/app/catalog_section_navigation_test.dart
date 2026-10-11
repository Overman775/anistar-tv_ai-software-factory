// Assertions observe identities and focus again after each section transition.
// ignore_for_file: prefer-moving-to-variable

import 'dart:async';

import 'package:anistar_tv/packages/features/catalog/catalog_providers.dart';
import 'package:anistar_tv/packages/features/catalog/domain/models/anime_page.dart';
import 'package:anistar_tv/packages/features/catalog/presentation/screens/catalog_screen.dart';
import 'package:anistar_tv/packages/features/catalog/presentation/widgets/anime_card.dart';
import 'package:anistar_tv/packages/features/catalog/presentation/widgets/catalog_navigation_rail.dart';
import 'package:anistar_tv/packages/features/favorites/favorites_providers.dart';
import 'package:anistar_tv/packages/features/home/presentation/screens/home_screen.dart';
import 'package:core/data.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../mocks/features/catalog/fake_catalog_screen_repository.dart';
import '../mocks/features/favorites/fake_favorites_repository.dart';
import '../support/test_app.dart';

void main() {
  for (final reducedMotion in [false, true]) {
    testWidgets('section changes preserve the expanded rail and focus at every frame (reduced=$reducedMotion)', (
      tester,
    ) async {
      final favorites = FakeFavoritesRepository();
      await pumpTvApp(
        tester,
        MediaQuery(
          data: MediaQueryData(disableAnimations: reducedMotion),
          child: HomeScreen(accountName: 'test', onAnimeTap: (_) => fail('Unexpected details')),
        ),
        wrapInScaffold: false,
        overrides: [
          catalogRepositoryProvider.overrideWithValue(const FakeCatalogScreenRepository()),
          favoritesRepositoryProvider.overrideWithValue(favorites),
        ],
      );
      await tester.pumpAndSettle();
      final rail = find.byType(CatalogNavigationRail);
      final railBox = find.byKey(const ValueKey('catalog-navigation-rail'));
      final railElement = tester.element(rail);
      final catalogState = tester.state(find.byType(CatalogScreen));
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      final home = tester.widget<TextButton>(find.byKey(const ValueKey('catalog-tab-false'))).focusNode;
      final favorite = tester.widget<TextButton>(find.byKey(const ValueKey('catalog-tab-true'))).focusNode;
      for (var transition = 0; transition < 4; transition++) {
        final toFavorites = transition.isEven;
        await tester.sendKeyEvent(toFavorites ? LogicalKeyboardKey.arrowDown : LogicalKeyboardKey.arrowUp);
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.select);
        for (final elapsed in [Duration.zero, const Duration(milliseconds: 80), const Duration(milliseconds: 240)]) {
          await tester.pump(elapsed);
          expect(tester.element(rail), same(railElement));
          expect(tester.state(find.byType(CatalogScreen)), same(catalogState));
          expect(tester.getSize(railBox).width, CatalogNavigationRail.expandedWidth);
          expect(FocusManager.instance.primaryFocus, same(toFavorites ? favorite : home));
          expect(find.ancestor(of: rail, matching: find.byType(Opacity)), findsNothing);
        }
        await tester.pumpAndSettle();
        expect(find.text('Избранное пусто'), toFavorites ? findsOneWidget : findsNothing);
      }
      expect(favorites.pages, [1, 1]);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(FocusManager.instance.primaryFocus?.context?.findAncestorWidgetOfExactType<AnimeCard>(), isNotNull);
      expect(tester.getSize(railBox).width, CatalogNavigationRail.collapsedWidth);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('a late home response cannot replace a newly selected favorites section', (tester) async {
    final pending = Completer<Result<AnimePage, Failure>>();
    final favorites = FakeFavoritesRepository()..ids.add(20);
    await pumpTvApp(
      tester,
      HomeScreen(onAnimeTap: (_) => fail('Unexpected details')),
      wrapInScaffold: false,
      overrides: [
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
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'Избранное');
    expect(tester.takeException(), isNull);
  });
}
