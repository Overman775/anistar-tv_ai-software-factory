import 'dart:async';

import 'package:anistar_tv/packages/features/auth/auth_providers.dart';
import 'package:anistar_tv/packages/features/catalog/catalog_providers.dart';
import 'package:anistar_tv/packages/features/catalog/domain/models/anime_page.dart';
import 'package:anistar_tv/packages/features/catalog/domain/models/anime_summary.dart';
import 'package:anistar_tv/packages/features/favorites/favorites_providers.dart';
import 'package:anistar_tv/packages/features/home/presentation/screens/home_screen.dart';
import 'package:core/data.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../../mocks/features/catalog/fake_catalog_screen_repository.dart';
import '../../../../../support/test_app.dart';

void main() {
  for (final profile in [GoldenProfile.tv, GoldenProfile.phonePortrait]) {
    testWidgets('catalog loading at ${profile.name}', (tester) async {
      final pending = Completer<Result<AnimePage, Failure>>();
      await testScreenGolden(
        tester,
        'catalog_loading',
        profile: profile,
        screen: _home,
        wrapInScaffold: false,
        overrides: [
          authAccessProvider.overrideWithValue(const AuthenticatedAccess('test')),
          favoritesAccountProvider.overrideWithValue('test'),
          catalogRepositoryProvider.overrideWithValue(FakeCatalogScreenRepository(load: (_) => pending.future)),
        ],
        prepare: (tester) async {
          await tester.pump();
          await tester.pump();
        },
      );
      expect(tester.takeException(), isNull);
    }, tags: ['golden']);

    testWidgets('catalog layout/focus at ${profile.name}', (tester) async {
      await testScreenGolden(
        tester,
        'catalog',
        profile: profile,
        screen: _home,
        wrapInScaffold: false,
        overrides: [
          authAccessProvider.overrideWithValue(const AuthenticatedAccess('test')),
          favoritesAccountProvider.overrideWithValue('test'),
          catalogRepositoryProvider.overrideWithValue(
            FakeCatalogScreenRepository(
              load: (_) async => Result.success(
                AnimePage(
                  page: 1,
                  hasNext: false,
                  items: List.generate(
                    12,
                    (index) => AnimeSummary(
                      id: index + 1,
                      slug: '${index + 1}-anime',
                      title: 'Аниме ${index + 1}',
                      posterUri: Uri(),
                      isFavorite: index == 0,
                      rating: index == 2 ? null : 8.4,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }, tags: ['golden']);
  }
}

final _home = HomeScreen(onAnimeTap: (anime) => expect(anime.id, isPositive));
