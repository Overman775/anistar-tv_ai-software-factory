import 'package:anistar_tv/packages/features/catalog/catalog_providers.dart';
import 'package:anistar_tv/packages/features/catalog/presentation/screens/catalog_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../../mocks/features/catalog/fake_catalog_screen_repository.dart';
import '../../../../../support/test_app.dart';

void main() {
  for (final (name, size) in [('compact', compactTvSize), ('wide', wideTvSize)]) {
    testWidgets('catalog layout/focus at $name viewport', (tester) async {
      await pumpTvApp(
        tester,
        CatalogScreen(onAnimeTap: (anime) => expect(anime.id, isPositive)),
        size: size,
        wrapInScaffold: false,
        overrides: [catalogRepositoryProvider.overrideWithValue(const FakeCatalogScreenRepository())],
      );
      await tester.pumpAndSettle();
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/catalog_$name.png'));
    }, tags: ['golden']);
  }
}
