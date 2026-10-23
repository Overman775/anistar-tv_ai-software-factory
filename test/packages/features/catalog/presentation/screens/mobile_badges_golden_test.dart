import 'package:anistar_tv/packages/features/auth/auth_providers.dart';
import 'package:anistar_tv/packages/features/catalog/catalog_providers.dart';
import 'package:anistar_tv/packages/features/catalog/domain/models/anime_page.dart';
import 'package:anistar_tv/packages/features/catalog/domain/models/anime_summary.dart';
import 'package:anistar_tv/packages/features/favorites/favorites_providers.dart';
import 'package:anistar_tv/packages/features/home/presentation/screens/home_screen.dart';
import 'package:core/data.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../../mocks/features/catalog/fake_catalog_screen_repository.dart';
import '../../../../../mocks/features/favorites/fake_favorites_repository.dart';
import '../../../../../support/test_app.dart';

void main() {
  for (final favorites in [false, true]) {
    testWidgets('mobile confirmed favorite omits desktop rating metadata favorites=$favorites', (tester) async {
      final page = AnimePage(
        page: 1,
        hasNext: false,
        items: const [
          AnimeSummary(id: 1, slug: '1-anime', title: 'Подтверждённое избранное', rating: 8.7, isFavorite: true),
          AnimeSummary(id: 2, slug: '2-anime', title: 'Без оценки', isFavorite: true),
        ],
      );
      final repository = FakeFavoritesRepository()..load = (_) async => Result.success(page);
      await pumpMobileApp(
        tester,
        HomeScreen(onAnimeTap: (_) => fail('Unexpected navigation')),
        disableAnimations: true,
        wrapInScaffold: false,
        overrides: [
          authAccessProvider.overrideWithValue(const AuthenticatedAccess('test')),
          favoritesAccountProvider.overrideWithValue('test'),
          catalogRepositoryProvider.overrideWithValue(
            FakeCatalogScreenRepository(load: (_) async => Result.success(page)),
          ),
          favoritesRepositoryProvider.overrideWithValue(repository),
        ],
      );
      // Each pump observes the preceding navigation state.
      // ignore: prefer-moving-to-variable
      await tester.pumpAndSettle();
      if (favorites) {
        await tester.tap(find.byType(NavigationDestination).at(2));
        // Each pump observes the preceding navigation state.
        // ignore: prefer-moving-to-variable
        await tester.pumpAndSettle();
      }
      expect(find.text('8,7'), findsNothing);
      expect(find.text('0,0'), findsNothing);
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/mobile_badges_${favorites ? 'favorites' : 'home'}_390.png'),
      );
    }, tags: ['golden']);
  }
}
