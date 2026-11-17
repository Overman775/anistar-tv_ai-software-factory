// Each scale verifies the same focus path and text containment.

import 'package:anistar_tv/packages/features/anime/presentation/widgets/anime_filter_row.dart';
import 'package:anistar_tv/packages/features/auth/auth_providers.dart';
import 'package:anistar_tv/packages/features/catalog/catalog_providers.dart';
import 'package:anistar_tv/packages/features/catalog/domain/models/catalog_filter.dart';
import 'package:anistar_tv/packages/features/catalog/presentation/widgets/anime_card.dart';
import 'package:anistar_tv/packages/features/catalog/presentation/widgets/catalog_navigation_rail.dart';
import 'package:anistar_tv/packages/features/favorites/favorites_providers.dart';
import 'package:anistar_tv/packages/features/home/presentation/screens/home_screen.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';

import '../mocks/features/catalog/fake_catalog_screen_repository.dart';
import '../mocks/features/favorites/fake_favorites_repository.dart';
import '../support/test_app.dart';

void main() {
  for (final scale in [1.3]) {
    testWidgets('filter text stays inside its row and remote focus reveals long labels at $scale', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final nodes = <String, FocusNode>{};
      addTearDown(() {
        for (final node in nodes.values) {
          node.dispose();
        }
      });
      const filters = [
        CatalogFilter(label: 'Повседневность', path: '/everyday/'),
        CatalogFilter(label: 'Приключения и фантастика', path: '/adventure/'),
        CatalogFilter(label: 'Детектив', path: '/detective/'),
      ];
      CatalogFilter? selected;
      int? focused;
      await pumpTvApp(
        tester,
        Align(
          alignment: Alignment.topLeft,
          child: AnimeFilterRow(
            filters: filters,
            focusNodes: nodes,
            onFocused: (index) => focused = index,
            onSelected: (filter) => selected = filter,
          ),
        ),
        size: const Size(640, 360),
      );
      nodes[filters.first.path]?.requestFocus();
      await tester.pumpAndSettle();
      final row = tester.getRect(find.byType(AnimeFilterRow));
      final text = tester.getRect(find.text(filters.first.label));
      expect(text.top, greaterThanOrEqualTo(row.top));
      expect(text.bottom, lessThanOrEqualTo(row.bottom));
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(FocusManager.instance.primaryFocus, same(nodes[filters[1].path]));
      expect(focused, 1);
      expect(find.text(filters[1].label).hitTestable(), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      expect(selected, filters[1]);
      expect(tester.takeException(), isNull);
    });

    testWidgets('expanded navigation fits account and remote actions at $scale', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final home = FocusNode();
      final favorites = FocusNode();
      addTearDown(home.dispose);
      addTearDown(favorites.dispose);
      var activated = false;
      await pumpTvApp(
        tester,
        CatalogNavigationRail(
          expanded: true,
          accountName: 'Пользователь с длинным именем',
          items: [
            (
              key: const ValueKey('home'),
              icon: Icons.home,
              label: 'Главная',
              focusNode: home,
              onPressed: () => fail('Unexpected home activation'),
              selected: true,
              autofocus: true,
            ),
            (
              key: const ValueKey('favorites'),
              icon: Icons.favorite,
              label: 'Избранное',
              focusNode: favorites,
              onPressed: () => activated = true,
              selected: false,
              autofocus: false,
            ),
          ],
        ),
        size: const Size(640, 360),
      );
      await tester.pumpAndSettle();
      expect(find.text('Пользователь с длинным именем').hitTestable(), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(FocusManager.instance.primaryFocus, same(favorites));
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      expect(activated, isTrue);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('production TV root keeps Sizer geometry DPR-independent and text inside roles', (tester) async {
    Future<void> pumpHome(double dpr, Size size) => pumpTvApp(
      tester,
      HomeScreen(onAnimeTap: (_) => fail('Unexpected activation')),
      size: size,
      devicePixelRatio: dpr,
      wrapInScaffold: false,
      disableAnimations: true,
      overrides: [
        authAccessProvider.overrideWithValue(const AuthenticatedAccess('test')),
        favoritesAccountProvider.overrideWithValue('test'),
        catalogRepositoryProvider.overrideWithValue(const FakeCatalogScreenRepository()),
        favoritesRepositoryProvider.overrideWithValue(FakeFavoritesRepository()),
      ],
    );

    void expectAppShell(Size size) {
      final rail = find.byKey(const ValueKey('catalog-navigation-rail'));
      final homeButton = find.byKey(const ValueKey('catalog-tab-false'));
      final homeIcon = find.descendant(of: homeButton, matching: find.byType(AppIcon));
      final card = find.byType(AnimeCard).first;
      final heading = tester.widget<Text>(find.text('Каталог аниме'));
      final title = tester
          .widgetList<Text>(find.text('Аниме 1'))
          .singleWhere((text) => (text.style?.fontSize ?? 0) > 20);

      expect(tester.getSize(rail).width, closeTo(size.width == 960 ? 72 : 88, 0.01));
      expect(tester.getSize(homeButton).height, closeTo(size.width == 960 ? 48 : 56, 0.01));
      expect(tester.getSize(homeIcon).width, closeTo(size.width == 960 ? 20 : 24, 0.01));
      expect(tester.getSize(card).width, closeTo(size.width == 960 ? 92 : 122.4, 0.01));
      expect(tester.getSize(card).height, closeTo((size.width == 960 ? 92 : 122.4) / AppSizes.posterRatio, 0.01));
      expect(heading.style?.fontSize, size.width == 960 ? closeTo(18, 0.01) : closeTo(20.06, 0.01));
      expect(title.style?.fontSize, inInclusiveRange(28, 56));
    }

    await pumpHome(1, compactTvSize);
    await tester.pumpAndSettle();
    expectAppShell(compactTvSize);
    await pumpHome(2, compactTvSize);
    await tester.pumpAndSettle();
    expectAppShell(compactTvSize);
    await tester.pumpWidget(const SizedBox.shrink());
    await pumpHome(1, wideTvSize);
    await tester.pumpAndSettle();
    expectAppShell(wideTvSize);
    final wideHeadingAtDpr1 =
        tester.widget<Text>(find.text('Каталог аниме')).style?.fontSize ??
        (throw TestFailure('TV rail heading must have a font size'));
    expect(wideHeadingAtDpr1, inExclusiveRange(18, 28));
    await pumpHome(2, wideTvSize);
    await tester.pumpAndSettle();
    final wideHeadingAtDpr2 =
        tester.widget<Text>(find.text('Каталог аниме')).style?.fontSize ??
        (throw TestFailure('TV rail heading must have a font size'));
    expect(wideHeadingAtDpr2, inExclusiveRange(18, 28));
    expect(wideHeadingAtDpr2, greaterThan(wideHeadingAtDpr1));
    expect(tester.getSize(find.byKey(const ValueKey('catalog-tab-false'))).height, closeTo(56, 0.01));
    expect(tester.takeException(), isNull);
  });
}
