// Pumps observe each routing and focus transition.

import 'package:anistar_tv/app/app_router.dart';
import 'package:anistar_tv/app/app_routes.dart';
import 'package:anistar_tv/packages/features/auth/auth_providers.dart';
import 'package:anistar_tv/packages/features/catalog/catalog_providers.dart';
import 'package:anistar_tv/packages/features/catalog/presentation/screens/catalog_screen.dart';
import 'package:anistar_tv/packages/features/favorites/favorites_providers.dart';
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
