import 'package:anistar_tv/packages/features/auth/auth_providers.dart';
import 'package:anistar_tv/packages/features/catalog/domain/models/anime_page.dart';
import 'package:anistar_tv/packages/features/catalog/domain/models/anime_summary.dart';
import 'package:anistar_tv/packages/features/search/presentation/search_screen.dart';
import 'package:anistar_tv/packages/features/search/search_providers.dart';
import 'package:core/data.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../mocks/features/search/fake_search_repository.dart';
import '../../../../support/test_app.dart';

void main() {
  for (final (mobile, size) in [
    (false, compactTvSize),
    (false, wideTvSize),
    (true, const Size(320, 640)),
    (true, const Size(390, 844)),
    (true, const Size(844, 390)),
  ]) {
    for (final textScale in [1.0, 2.0]) {
      for (final scene in ['history', 'results', 'empty', 'error']) {
        final profile = mobile ? 'mobile' : 'tv';
        final dimensions = '${size.width.toInt()}x${size.height.toInt()}';
        final scale = (textScale * 100).toInt();
        final legacy = textScale == 1 && size == (mobile ? const Size(390, 844) : compactTvSize);
        final suffix = legacy ? '' : '_${dimensions}_$scale';
        testWidgets('guest search $scene $profile $dimensions $scale% golden', (tester) async {
          final semantics = tester.ensureSemantics();
          try {
            final opened = <int>[];
            final settle = tester.pumpAndSettle;
            final takeException = tester.takeException;
            final repository = FakeSearchRepository(
              load: (_) async => scene == 'error'
                  ? const Result.failure(UnknownFailure())
                  : Result.success(
                      AnimePage(
                        items: scene == 'results'
                            ? List.generate(
                                6,
                                (index) => AnimeSummary(
                                  id: index + 1,
                                  slug: '${index + 1}-anime',
                                  title: 'Аниме ${index + 1}',
                                ),
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
            final screen = SearchScreen(onAnimeTap: (anime) => opened.add(anime.id));
            if (mobile) {
              await pumpMobileApp(
                tester,
                screen,
                size: size,
                textScale: textScale,
                overrides: overrides,
                disableAnimations: true,
              );
            } else {
              await pumpTvApp(
                tester,
                MediaQuery(
                  data: MediaQueryData(disableAnimations: true, textScaler: TextScaler.linear(textScale)),
                  child: screen,
                ),
                size: size,
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
            final layoutException = takeException();
            expect(layoutException, isNull);
            await expectLater(
              find.byType(MaterialApp),
              matchesGoldenFile('goldens/search_${profile}_$scene$suffix.png'),
            );
            _expectAction(tester, find.byKey(const ValueKey('search-submit')), 'Найти');
            final field = find.byKey(const ValueKey('search-query'));
            final controller = tester.widget<TextField>(field).controller;
            expect(find.bySemanticsLabel(RegExp('Название аниме')), findsWidgets);
            if (scene == 'history') {
              final recent = find.byKey(const ValueKey('search-recent-0'));
              _expectAction(tester, recent, 'Наруто');
              _expectAction(tester, find.byKey(const ValueKey('search-remove-0')), 'Удалить запрос Наруто');
              _expectAction(tester, find.widgetWithText(TextButton, 'Очистить'), 'Очистить');
              await tester.tap(find.byKey(const ValueKey('search-remove-1')));
              await settle();
              expect(find.byKey(const ValueKey('search-recent-1')), findsNothing);
              await tester.tap(recent);
              await settle();
              expect(repository.requests.single.query, 'Наруто');
            } else if (scene == 'results') {
              final card = find.byKey(const ValueKey('search-card-1'));
              await tester.ensureVisible(card);
              await settle();
              _expectAction(tester, card, 'Аниме 1');
              await tester.tap(card);
              await settle();
              expect(opened, [1]);
            } else {
              expect(find.text(scene == 'empty' ? 'Ничего не найдено' : 'Поиск недоступен'), findsOneWidget);
            }
            final clear = find.byKey(const ValueKey('search-clear'));
            _expectAction(tester, clear, 'Очистить запрос');
            await tester.tap(clear);
            await settle();
            expect(controller?.text, isEmpty);
            controller?.text = 'Ван Пис';
            final requestCount = repository.requests.length;
            await tester.tap(find.byKey(const ValueKey('search-submit')));
            await settle();
            expect(repository.requests.length, requestCount + 1);
            expect(repository.requests.last.query, 'Ван Пис');
            final interactionException = takeException();
            expect(interactionException, isNull);
          } finally {
            semantics.dispose();
          }
        }, tags: ['golden']);
      }
    }
  }
}

void _expectAction(WidgetTester tester, Finder finder, String label) {
  expect(finder.hitTestable(), findsOneWidget);
  final nodes = [tester.getSemantics(finder)];
  for (var index = 0; index < nodes.length; index++) {
    nodes[index].visitChildren((child) {
      nodes.add(child);

      return true;
    });
  }
  final data = nodes.map((node) => node.getSemanticsData()).toList();
  expect(data.map((node) => '${node.label} ${node.tooltip}').join(' '), contains(label));
  expect(data.any((node) => node.hasAction(SemanticsAction.tap)), isTrue);
  final size = tester.getSize(finder);
  final minimumSize = greaterThanOrEqualTo(48);
  expect(size.width, minimumSize);
  expect(size.height, minimumSize);
}
