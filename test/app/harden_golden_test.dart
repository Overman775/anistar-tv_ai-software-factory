import 'package:anistar_tv/packages/features/auth/auth_providers.dart';
import 'package:anistar_tv/packages/features/auth/presentation/login_screen.dart';
import 'package:anistar_tv/packages/features/catalog/catalog_providers.dart';
import 'package:anistar_tv/packages/features/catalog/domain/models/catalog_filter.dart';
import 'package:anistar_tv/packages/features/catalog/presentation/screens/genres_screen.dart';
import 'package:anistar_tv/packages/features/home/presentation/home_destination.dart';
import 'package:anistar_tv/packages/features/home/presentation/screens/tv_route_shell.dart';
import 'package:core/data.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';

import '../mocks/features/auth/fake_auth_repository.dart';
import '../mocks/features/catalog/fake_catalog_browse_repository.dart';
import '../support/test_app.dart';

void main() {
  testWidgets('long recovery state at 200% on TV', (tester) async {
    await testScreenGolden(
      tester,
      'harden_error',
      textScale: GoldenTextScale.large,
      screen: TvBackdrop(
        child: TvStateView(
          icon: Icons.cloud_off_rounded,
          title: 'Каталог недоступен',
          message: 'Не удалось получить данные AniStar. Проверьте подключение к интернету и повторите загрузку. Ваши изменения в аккаунте сохраняются на сайте.',
          actionLabel: 'Повторить',
          onAction: () => fail('Unexpected retry'),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    final title = find.text('Каталог недоступен');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(title).dy, greaterThanOrEqualTo(0));
    expect(tester.getBottomRight(title).dy, lessThanOrEqualTo(GoldenProfile.tv.logicalSize.height));
    expect(tester.takeException(), isNull);
  }, tags: ['golden']);

  testWidgets('portrait login at 200%', (tester) async {
    final repository = FakeAuthRepository();
    addTearDown(repository.close);
    await testScreenGolden(
      tester,
      'harden_login',
      profile: GoldenProfile.phonePortrait,
      textScale: GoldenTextScale.large,
      screen: const LoginScreen(),
      wrapInScaffold: false,
      overrides: [authRepositoryProvider.overrideWithValue(repository)],
    );
    expect(tester.takeException(), isNull);
  }, tags: ['golden']);

  testWidgets('long portrait genres at 200%', (tester) async {
    final items = List.generate(
      50,
      (index) => CatalogFilter(label: 'Научная фантастика и путешествия $index', path: '/genre-$index/'),
    );
    await testScreenGolden(
      tester,
      'harden_genres',
      profile: GoldenProfile.phonePortrait,
      textScale: GoldenTextScale.large,
      screen: TvRouteShell(
        destination: HomeDestination.genres,
        onDestinationSelected: (_) => fail('Unexpected destination selection'),
        builder: (onOpenNavigation) =>
            GenresScreen(onOpenNavigation: onOpenNavigation, onSelected: (_) => fail('Unexpected selection')),
      ),
      wrapInScaffold: false,
      overrides: [
        catalogBrowseRepositoryProvider.overrideWithValue(
          FakeCatalogBrowseRepository(genres: () async => Result.success(items)),
        ),
      ],
    );
    expect(tester.takeException(), isNull);
  }, tags: ['golden']);
}
