import 'dart:async';

import 'package:anistar_tv/packages/features/auth/auth_providers.dart';
import 'package:anistar_tv/packages/features/catalog/domain/models/anime_page.dart';
import 'package:anistar_tv/packages/features/catalog/domain/models/anime_summary.dart';
import 'package:anistar_tv/packages/features/catalog/presentation/widgets/catalog_layout.dart';
import 'package:anistar_tv/packages/features/catalog/presentation/widgets/catalog_skeleton.dart';
import 'package:anistar_tv/packages/features/search/presentation/search_loading.dart';
import 'package:anistar_tv/packages/features/search/presentation/search_screen.dart';
import 'package:anistar_tv/packages/features/search/search_providers.dart';
import 'package:core/data.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';

import '../../../../mocks/features/search/fake_search_repository.dart';
import '../../../../support/test_app.dart';

void main() {
  // This matrix owns visual states across profile, viewport and text scale.
  // Query rules and retry semantics stay covered by SearchBloc/SearchScreen tests.
  for (final (mobile, size) in [
    (false, compactTvSize),
    (false, wideTvSize),
    (false, const Size(1920, 1080)),
    (true, const Size(320, 640)),
    (true, const Size(390, 844)),
    (true, const Size(844, 390)),
  ]) {
    for (final textScale in [1.0, 2.0]) {
      for (final scene in [
        'idle',
        'history',
        'loading',
        'results',
        'empty',
        'validation',
        'error',
        'pagination_retry',
      ]) {
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
            final pending = Completer<Result<AnimePage, Failure>>();
            final repository = FakeSearchRepository(
              load: (request) async {
                if (scene == 'loading') {
                  return pending.future;
                }
                if (scene == 'error') {
                  return const Result.failure(UnknownFailure());
                }
                if (scene == 'pagination_retry' && request.page == 2) {
                  return const Result.failure(UnknownFailure());
                }

                return Result.success(
                  AnimePage(
                    items: switch (scene) {
                      'results' => List.generate(
                        6,
                        (index) => AnimeSummary(id: index + 1, slug: '${index + 1}-anime', title: 'Аниме ${index + 1}'),
                      ),
                      'pagination_retry' => List.generate(
                        24,
                        (index) => AnimeSummary(id: index + 1, slug: '${index + 1}-anime', title: 'Аниме ${index + 1}'),
                      ),
                      _ => const [],
                    },
                    page: request.page,
                    hasNext: scene == 'pagination_retry' && request.page == 1,
                  ),
                );
              },
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
                screen,
                size: size,
                textScale: textScale,
                disableAnimations: true,
                overrides: overrides,
              );
            }
            await settle();
            if (!['idle', 'history'].contains(scene)) {
              final field = find.byKey(const ValueKey('search-query'));
              tester.widget<TextField>(field).controller?.text = scene == 'validation' ? 'abc' : 'Наруто';
              await tester.tap(find.byKey(const ValueKey('search-submit')));
              if (scene == 'loading') {
                await tester.pump();
              } else {
                await settle();
              }
            }
            if (scene == 'pagination_retry') {
              if (mobile) {
                final scroll = tester
                    .widget<SingleChildScrollView>(find.byKey(const PageStorageKey('search-results')))
                    .controller;
                scroll?.jumpTo(scroll.position.maxScrollExtent);
                await settle();
                await tester.ensureVisible(find.byKey(const ValueKey('search-pagination-retry')));
                await settle();
              } else {
                await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
                await settle();
                for (var index = 0; index < 24; index++) {
                  await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
                  await tester.pump(const Duration(milliseconds: 300));
                }
                expect(repository.requests.map((request) => request.page), [1, 2]);
                expect(find.byKey(const ValueKey('search-pagination-retry')).hitTestable(), findsOneWidget);
              }
            }
            if (!mobile && scene == 'loading') {
              final skeleton = find.byType(CatalogSkeleton);
              final row = find.descendant(of: skeleton, matching: find.byType(ListView));
              expect(tester.widget<ListView>(row).scrollDirection, Axis.horizontal);
              final placeholders = find.descendant(of: row, matching: find.byType(TvSkeletonBox));
              final first = placeholders.first;
              expect(tester.getSize(first).width, closeTo(CatalogLayout.posterWidth(size.height), 0.01));
              expect(
                tester.getBottomLeft(first).dy,
                closeTo(tester.getBottomLeft(find.byType(SearchLoading)).dy - CatalogLayout.railBottomPadding, 0.01),
              );
            }
            if (!mobile && scene == 'pagination_retry' && textScale == 2 && size != const Size(1920, 1080)) {
              for (final label in ['Сбой', 'Ещё раз']) {
                final text = find.descendant(
                  of: find.byKey(const ValueKey('search-pagination-retry')),
                  matching: find.text(label),
                );
                expect(text, findsOneWidget);
                expect(
                  tester.renderObject<RenderParagraph>(text).didExceedMaxLines,
                  isFalse,
                  reason: '$label must stay legible',
                );
              }
            }
            if (mobile && size == const Size(320, 640) && textScale == 2) {
              final label = switch (scene) {
                'history' => 'Последние запросы',
                'error' => 'Поиск недоступен',
                _ => null,
              };
              if (label != null) {
                final paragraph = tester.renderObject<RenderParagraph>(find.text(label));
                var start = 0;
                for (final word in label.split(' ')) {
                  expect(
                    paragraph
                        .getBoxesForSelection(TextSelection(baseOffset: start, extentOffset: start + word.length))
                        .length,
                    1,
                    reason: '$word must not split across lines',
                  );
                  start += word.length + 1;
                }
              }
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
            if (scene == 'idle') {
              expect(find.text('Что будем смотреть?'), findsOneWidget);
            } else if (scene == 'history') {
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
              expect(card, findsOneWidget);
              expect(opened, isEmpty);
            } else if (scene == 'loading') {
              expect(find.text('Ищем аниме…'), findsOneWidget);
            } else if (scene == 'validation') {
              expect(find.text('Введите не менее 4 символов.'), findsOneWidget);
            } else if (scene == 'pagination_retry') {
              expect(find.byKey(const ValueKey('search-pagination-retry')), findsOneWidget);
            } else {
              expect(find.text(scene == 'empty' ? 'Ничего не найдено' : 'Поиск недоступен'), findsOneWidget);
            }
            final clear = find.byKey(const ValueKey('search-clear'));
            if (!['idle', 'loading'].contains(scene)) {
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
            }
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
