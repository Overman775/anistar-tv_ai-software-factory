// Each scale verifies the same focus path and text containment.

import 'package:anistar_tv/packages/features/anime/presentation/widgets/anime_filter_row.dart';
import 'package:anistar_tv/packages/features/catalog/domain/models/catalog_filter.dart';
import 'package:anistar_tv/packages/features/catalog/presentation/widgets/catalog_navigation_rail.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../support/test_app.dart';

void main() {
  for (final scale in [1.3, 2.0]) {
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
}
