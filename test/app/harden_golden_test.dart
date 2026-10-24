import 'package:anistar_tv/packages/features/auth/auth_providers.dart';
import 'package:anistar_tv/packages/features/auth/presentation/login_screen.dart';
import 'package:anistar_tv/packages/features/catalog/catalog_providers.dart';
import 'package:anistar_tv/packages/features/catalog/domain/models/catalog_filter.dart';
import 'package:anistar_tv/packages/features/catalog/presentation/screens/genres_screen.dart';
import 'package:anistar_tv/packages/features/home/presentation/home_destination.dart';
import 'package:anistar_tv/packages/features/home/presentation/screens/tv_route_shell.dart';
import 'package:core/data.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';

import '../mocks/features/auth/fake_auth_repository.dart';
import '../mocks/features/catalog/fake_catalog_browse_repository.dart';
import '../support/test_app.dart';

void main() {
  for (final (name, size) in [('compact', compactTvSize), ('wide', wideTvSize)]) {
    testWidgets('long recovery state at 200% on $name TV', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpTvApp(
        tester,
        TvBackdrop(
          child: TvStateView(
            icon: Icons.cloud_off_rounded,
            title: 'Каталог недоступен',
            message: 'Не удалось получить данные AniStar. Проверьте подключение к интернету и повторите загрузку. Ваши изменения в аккаунте сохраняются на сайте.',
            actionLabel: 'Повторить',
            onAction: () => fail('Unexpected retry'),
          ),
        ),
        size: size,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/harden_error_${name}_scaled.png'));
    }, tags: ['golden']);
  }

  testWidgets('portrait login at 200%', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final repository = FakeAuthRepository();
    addTearDown(repository.close);
    await pumpTvApp(
      tester,
      const LoginScreen(),
      size: const Size(390, 844),
      wrapInScaffold: false,
      overrides: [authRepositoryProvider.overrideWithValue(repository)],
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/harden_login_portrait_scaled.png'));
  }, tags: ['golden']);

  testWidgets('long portrait genres at 200%', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final items = List.generate(
      50,
      (index) => CatalogFilter(label: 'Научная фантастика и путешествия $index', path: '/genre-$index/'),
    );
    await pumpTvApp(
      tester,
      TvRouteShell(
        destination: HomeDestination.genres,
        onDestinationSelected: (_) => fail('Unexpected destination selection'),
        builder: (onOpenNavigation) =>
            GenresScreen(onOpenNavigation: onOpenNavigation, onSelected: (_) => fail('Unexpected selection')),
      ),
      size: const Size(390, 844),
      wrapInScaffold: false,
      overrides: [
        catalogBrowseRepositoryProvider.overrideWithValue(
          FakeCatalogBrowseRepository(genres: () async => Result.success(items)),
        ),
      ],
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/harden_genres_portrait_scaled.png'));
  }, tags: ['golden']);
}
