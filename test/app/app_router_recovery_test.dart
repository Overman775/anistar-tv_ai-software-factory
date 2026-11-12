// Pumps observe each routing and focus transition.

import 'package:anistar_tv/app/app_router.dart';
import 'package:anistar_tv/app/app_routes.dart';
import 'package:anistar_tv/packages/features/auth/auth_providers.dart';
import 'package:anistar_tv/packages/features/catalog/catalog_providers.dart';
import 'package:anistar_tv/packages/features/catalog/presentation/screens/catalog_screen.dart';
import 'package:anistar_tv/packages/features/catalog/presentation/widgets/anime_card.dart';
import 'package:anistar_tv/packages/features/catalog/presentation/widgets/catalog_navigation_rail.dart';
import 'package:anistar_tv/packages/features/favorites/favorites_providers.dart';
import 'package:anistar_tv/packages/features/home/presentation/screens/home_screen.dart';
import 'package:app_logging/app_logging.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';

import '../mocks/features/auth/fake_auth_repository.dart';
import '../mocks/features/catalog/fake_catalog_screen_repository.dart';
import '../mocks/features/favorites/fake_favorites_repository.dart';
import '../support/test_app.dart';

void main() {
  testWidgets('TV menu preserves current content focus and separates selected from focused', (tester) async {
    await pumpTvApp(
      tester,
      HomeScreen(accountName: 'viewer', onAnimeTap: (_) => fail('Unexpected anime')),
      wrapInScaffold: false,
      overrides: [
        authAccessProvider.overrideWithValue(const AuthenticatedAccess('viewer')),
        favoritesAccountProvider.overrideWithValue('viewer'),
        catalogRepositoryProvider.overrideWithValue(const FakeCatalogScreenRepository()),
        favoritesRepositoryProvider.overrideWithValue(FakeFavoritesRepository()),
      ],
    );
    await tester.pumpAndSettle();
    final rail = find.byType(CatalogNavigationRail);
    final frame = find.byKey(const ValueKey('catalog-navigation-rail'));
    expect(tester.getSize(frame).width, 88);
    final homeButton = find.byKey(const ValueKey('catalog-tab-false'));
    final homeIcon = find.descendant(of: homeButton, matching: find.byType(AppIcon));
    expect(tester.getSize(homeButton).height, 56);
    expect(tester.getSize(homeIcon), const Size(24, 24));
    final iconAxis = tester.getCenter(homeIcon).dx;
    final selectedContent = FocusManager.instance.primaryFocus;
    expect(selectedContent?.context?.findAncestorWidgetOfExactType<AnimeCard>(), isNotNull);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    expect(tester.getSize(frame).width, inExclusiveRange(88, 264));
    await tester.pumpAndSettle();
    expect(tester.getSize(frame).width, 264);
    expect(tester.getCenter(homeIcon).dx, closeTo(iconAxis, 0.01));
    expect(find.text('viewer'), findsOneWidget);
    final home = tester
        .widget<CatalogNavigationRail>(rail)
        .items
        .singleWhere((item) => item.key == const ValueKey('catalog-tab-false'));
    expect(home.selected, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(FocusManager.instance.primaryFocus, isNot(same(home.focusNode)));
    expect(
      tester.widget<CatalogNavigationRail>(rail).items.singleWhere((item) => item.key == home.key).selected,
      isTrue,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(tester.getSize(frame).width, 88);
    expect(FocusManager.instance.primaryFocus, same(selectedContent));
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(FocusManager.instance.primaryFocus, same(selectedContent));
    expect(tester.takeException(), isNull);
  });

  testWidgets('explicit guest menu offers sign-in and keeps public catalog available', (tester) async {
    var signInCalls = 0;
    await pumpTvApp(
      tester,
      HomeScreen(onAnimeTap: (_) => fail('Unexpected anime'), onSignIn: () => signInCalls++),
      wrapInScaffold: false,
      overrides: [
        authAccessProvider.overrideWithValue(const AnonymousAccess()),
        catalogRepositoryProvider.overrideWithValue(const FakeCatalogScreenRepository()),
        favoritesRepositoryProvider.overrideWithValue(FakeFavoritesRepository()),
      ],
    );
    await tester.pumpAndSettle();
    expect(find.byType(AnimeCard), findsWidgets);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    final rail = tester.widget<CatalogNavigationRail>(find.byType(CatalogNavigationRail));
    expect(rail.expanded, isTrue);
    expect(rail.items.map((item) => item.label), contains('Войти'));
    rail.items.singleWhere((item) => item.label == 'Войти').onPressed();
    expect(signInCalls, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('invalid route hides URI details and remote OK returns to catalog', (tester) async {
    final auth = FakeAuthRepository();
    addTearDown(auth.close);
    final appRouter = AppRouter(AppLogger.logger);
    addTearDown(appRouter.dispose);
    await pumpTvApp(
      tester,
      MaterialApp.router(routerConfig: appRouter.router, theme: AppTheme.darkTheme),
      wrapInScaffold: false,
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        catalogRepositoryProvider.overrideWithValue(const FakeCatalogScreenRepository()),
        favoritesRepositoryProvider.overrideWithValue(FakeFavoritesRepository()),
      ],
    );
    await tester.pumpAndSettle();
    appRouter.router.go('/missing?token=private-value');
    await tester.pumpAndSettle();
    expect(find.text('Страница недоступна'), findsOneWidget);
    expect(find.textContaining('private-value'), findsNothing);
    final recover = find.widgetWithText(AppButton, 'На главную');
    expect(recover.hitTestable(), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(appRouter.router.routeInformationProvider.value.uri.path, AppRoutes.home);
    expect(find.byType(CatalogScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
