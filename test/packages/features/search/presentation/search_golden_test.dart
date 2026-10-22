import 'package:anistar_tv/packages/features/auth/auth_providers.dart';
import 'package:anistar_tv/packages/features/catalog/domain/models/anime_page.dart';
import 'package:anistar_tv/packages/features/catalog/domain/models/anime_summary.dart';
import 'package:anistar_tv/packages/features/search/presentation/search_screen.dart';
import 'package:anistar_tv/packages/features/search/search_providers.dart';
import 'package:core/data.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../mocks/features/search/fake_search_repository.dart';
import '../../../../support/test_app.dart';

void main() {
  for (final mobile in [false, true]) {
    for (final scene in ['history', 'results', 'empty', 'error']) {
      testWidgets('guest search $scene ${mobile ? 'mobile' : 'tv'} golden', (tester) async {
        final settle = tester.pumpAndSettle;
        final repository = FakeSearchRepository(
          load: (_) async => scene == 'error'
              ? const Result.failure(UnknownFailure())
              : Result.success(
                  AnimePage(
                    items: scene == 'results'
                        ? List.generate(
                            6,
                            (index) =>
                                AnimeSummary(id: index + 1, slug: '${index + 1}-anime', title: 'Аниме ${index + 1}'),
                          )
                        : const [],
                    page: 1,
                    hasNext: false,
                  ),
                ),
        );
        final overrides = [
          authAccessProvider.overrideWithValue(const AnonymousAccess()),
          searchRepositoryProvider.overrideWithValue(repository),
          searchHistoryRepositoryProvider.overrideWithValue(
            FakeSearchHistoryRepository(scene == 'history' ? ['Наруто', 'Ван Пис'] : const []),
          ),
        ];
        final screen = SearchScreen(onAnimeTap: (_) => fail('Unexpected detail'));
        if (mobile) {
          await pumpMobileApp(tester, screen, overrides: overrides, disableAnimations: true);
        } else {
          await pumpTvApp(
            tester,
            MediaQuery(data: const MediaQueryData(disableAnimations: true), child: screen),
            overrides: overrides,
          );
        }
        await settle();
        if (scene != 'history') {
          final field = find.byKey(const ValueKey('search-query'));
          tester.widget<TextField>(field).controller?.text = 'Наруто';
          await tester.tap(find.byKey(const ValueKey('search-submit')));
          await settle();
        }
        expect(tester.takeException(), isNull);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/search_${mobile ? 'mobile' : 'tv'}_$scene.png'),
        );
      }, tags: ['golden']);
    }
  }
}
