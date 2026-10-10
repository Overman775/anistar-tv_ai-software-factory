import 'dart:async';

import 'package:anistar_tv/packages/features/catalog/catalog_providers.dart';
import 'package:anistar_tv/packages/features/catalog/domain/models/anime_page.dart';
import 'package:anistar_tv/packages/features/catalog/presentation/screens/catalog_screen.dart';
import 'package:core/data.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../../mocks/features/catalog/fake_catalog_screen_repository.dart';
import '../../../../../support/test_app.dart';

void main() {
  for (final (name, size) in [('compact', compactTvSize), ('wide', wideTvSize)]) {
    testWidgets('catalog loading at $name viewport', (tester) async {
      final pending = Completer<Result<AnimePage, Failure>>();
      await pumpTvApp(
        tester,
        MediaQuery(
          data: MediaQueryData(size: size, disableAnimations: true),
          child: CatalogScreen(
            onAnimeTap: (_) => fail('Unexpected anime activation'),
            onTabSelected: (_) => fail('Unexpected tab activation'),
          ),
        ),
        size: size,
        wrapInScaffold: false,
        overrides: [
          catalogRepositoryProvider.overrideWithValue(FakeCatalogScreenRepository(load: (_) => pending.future)),
        ],
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/catalog_loading_$name.png'));
    }, tags: ['golden']);
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
