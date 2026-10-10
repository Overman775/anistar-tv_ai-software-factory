import 'package:anistar_tv/packages/features/catalog/catalog_providers.dart';
import 'package:anistar_tv/packages/features/catalog/domain/models/anime_page.dart';
import 'package:anistar_tv/packages/features/catalog/domain/models/anime_summary.dart';
import 'package:anistar_tv/packages/features/catalog/presentation/screens/catalog_screen.dart';
import 'package:anistar_tv/packages/features/favorites/favorites_providers.dart';
import 'package:anistar_tv/packages/features/home/presentation/screens/home_screen.dart';
import 'package:core/data.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../../mocks/features/catalog/fake_catalog_screen_repository.dart';
import '../../../mocks/features/favorites/fake_favorites_repository.dart';
import '../../../support/test_app.dart';

void main() {
  for (final (name, size) in [('compact', compactTvSize), ('wide', wideTvSize)]) {
    testWidgets('main tabs and confirmed favorite badge at $name', (tester) async {
      final repository = FakeCatalogScreenRepository(
        load: (_) async => Result.success(
          AnimePage(
            items: List.generate(
              12,
              (index) => AnimeSummary(
                id: index + 1,
                slug: '${index + 1}-test',
                title: 'Аниме ${index + 1}',
                posterUri: Uri(),
                isFavorite: index == 0,
              ),
            ),
            page: 1,
            hasNext: false,
          ),
        ),
      );
      await pumpTvApp(
        tester,
        HomeScreen(onAnimeTap: (_) => fail('Unexpected navigation')),
        size: size,
        wrapInScaffold: false,
        overrides: [catalogRepositoryProvider.overrideWithValue(repository)],
      );
      await tester.pumpAndSettle();
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/main_$name.png'));
    }, tags: ['golden']);

    testWidgets('favorites tab and website row at $name', (tester) async {
      final repository = FakeFavoritesRepository()..ids.add(1);
      await pumpTvApp(
        tester,
        CatalogScreen(
          favoritesOnly: true,
          onAnimeTap: (_) => fail('Unexpected navigation'),
          onTabSelected: (_) => fail('Unexpected tab change'),
        ),
        size: size,
        wrapInScaffold: false,
        overrides: [favoritesRepositoryProvider.overrideWithValue(repository)],
      );
      await tester.pumpAndSettle();
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/favorites_$name.png'));
    }, tags: ['golden']);
  }
}
