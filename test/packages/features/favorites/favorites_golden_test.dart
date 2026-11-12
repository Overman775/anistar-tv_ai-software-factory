// Each pump and snapshot observes a distinct navigation state.

import 'package:anistar_tv/packages/features/auth/auth_providers.dart';
import 'package:anistar_tv/packages/features/catalog/catalog_providers.dart';
import 'package:anistar_tv/packages/features/favorites/favorites_providers.dart';
import 'package:anistar_tv/packages/features/favorites/presentation/favorite_actions_sheet.dart';
import 'package:anistar_tv/packages/features/home/presentation/home_destination.dart';
import 'package:anistar_tv/packages/features/home/presentation/screens/home_screen.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../../mocks/features/catalog/fake_catalog_screen_repository.dart';
import '../../../mocks/features/favorites/fake_favorites_repository.dart';
import '../../../support/test_app.dart';

void main() {
  testWidgets('TV expanded menu reveals logout and logs at 960x540 and 200%', (tester) async {
    await pumpTvApp(
      tester,
      HomeScreen(
        onAnimeTap: (_) => fail('Unexpected navigation'),
        onSignOut: () => fail('Unexpected logout'),
        onOpenLogs: () => fail('Unexpected logs'),
        accountName: 'Тестовый пользователь',
      ),
      textScale: 2,
      disableAnimations: true,
      wrapInScaffold: false,
      overrides: [
        authAccessProvider.overrideWithValue(const AuthenticatedAccess('test')),
        favoritesAccountProvider.overrideWithValue('test'),
        catalogRepositoryProvider.overrideWithValue(const FakeCatalogScreenRepository()),
      ],
    );
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    final list = find.descendant(
      of: find.byKey(const ValueKey('catalog-navigation-rail')),
      matching: find.byType(ListView),
    );
    for (var i = 0; i < 4; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
    }
    final logout = find.byKey(const ValueKey('catalog-account'));
    expect(tester.widget<TextButton>(logout).focusNode?.hasFocus, isTrue);
    final logoutBottom = tester.getBottomLeft(logout).dy;
    final listBottom = tester.getBottomLeft(list).dy;
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    final logs = find.byKey(const ValueKey('catalog-logs'));
    expect(logs, findsOneWidget, reason: 'Down must reveal the next menu item');
    expect(tester.widget<TextButton>(logs).focusNode?.hasFocus, isTrue);
    final logsBottom = tester.getBottomLeft(logs).dy;
    expect([logoutBottom, logsBottom], everyElement(lessThanOrEqualTo(listBottom)));
    expect(tester.takeException(), isNull);
  });

  for (final (name, size) in [('compact', compactTvSize), ('wide', wideTvSize)]) {
    testWidgets('expanded navigation and right action sheet at $name', (tester) async {
      await pumpTvApp(
        tester,
        HomeScreen(
          onAnimeTap: (_) => fail('Unexpected activation'),
          onSignOut: () => fail('Unexpected logout'),
          onOpenLogs: () => fail('Unexpected logs'),
          onOpenGenres: () => fail('Unexpected genres'),
          accountName: 'anime_fan',
        ),
        size: size,
        wrapInScaffold: false,
        overrides: [
          authAccessProvider.overrideWithValue(const AuthenticatedAccess('test')),
          favoritesAccountProvider.overrideWithValue('test'),
          catalogRepositoryProvider.overrideWithValue(const FakeCatalogScreenRepository()),
          favoritesRepositoryProvider.overrideWithValue(FakeFavoritesRepository()),
        ],
      );
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/navigation_expanded_$name.png'));
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.select);
      await tester.sendKeyRepeatEvent(LogicalKeyboardKey.select);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.select);
      await tester.pumpAndSettle();
      expect(find.byType(FavoriteActionsSheet), findsOneWidget);
      expect(tester.takeException(), isNull);
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/actions_sheet_$name.png'));
    }, tags: ['golden']);

    testWidgets('favorites tab and website row at $name', (tester) async {
      final repository = FakeFavoritesRepository()..ids.add(1);
      await pumpTvApp(
        tester,
        HomeScreen(destination: HomeDestination.favorites, onAnimeTap: (_) => fail('Unexpected navigation')),
        size: size,
        wrapInScaffold: false,
        overrides: [
          authAccessProvider.overrideWithValue(const AuthenticatedAccess('test')),
          favoritesAccountProvider.overrideWithValue('test'),
          favoritesRepositoryProvider.overrideWithValue(repository),
        ],
      );
      await tester.pumpAndSettle();
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/favorites_$name.png'));
    }, tags: ['golden']);
  }
}
