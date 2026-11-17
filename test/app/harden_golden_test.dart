import 'package:anistar_tv/packages/features/auth/auth_providers.dart';
import 'package:anistar_tv/packages/features/auth/presentation/login_screen.dart';
import 'package:anistar_tv/packages/features/catalog/catalog_providers.dart';
import 'package:anistar_tv/packages/features/catalog/domain/models/catalog_filter.dart';
import 'package:anistar_tv/packages/features/catalog/presentation/screens/genres_screen.dart';
import 'package:anistar_tv/packages/features/home/presentation/home_destination.dart';
import 'package:anistar_tv/packages/features/home/presentation/screens/tv_route_shell.dart';
import 'package:core/data.dart';
import 'package:flutter_test/flutter_test.dart';

import '../mocks/features/auth/fake_auth_repository.dart';
import '../mocks/features/catalog/fake_catalog_browse_repository.dart';
import '../support/test_app.dart';

void main() {
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
