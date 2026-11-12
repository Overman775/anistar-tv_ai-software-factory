import 'dart:async';

import 'package:anistar_tv/packages/features/anime/anime_providers.dart';
import 'package:anistar_tv/packages/features/anime/domain/models/anime_details.dart';
import 'package:anistar_tv/packages/features/anime/domain/models/anime_episode.dart';
import 'package:anistar_tv/packages/features/anime/domain/models/anime_part.dart';
import 'package:anistar_tv/packages/features/anime/domain/models/anime_screen_data.dart';
import 'package:anistar_tv/packages/features/anime/presentation/screens/anime_screen.dart';
import 'package:anistar_tv/packages/features/anime/presentation/widgets/mobile_anime_content.dart';
import 'package:anistar_tv/packages/features/catalog/domain/models/catalog_filter.dart';
import 'package:core/data.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';

import '../../../../../mocks/features/anime/fake_anime_screen_repository.dart';
import '../../../../../support/test_app.dart';

// Widget state and layout are sampled again after each gesture and network response.

const _title = 'Пожалуйста, простите моих младших братьев / Please Forgive My Younger Brothers';
final _data = AnimeScreenData(
  details: AnimeDetails(
    id: 1,
    slug: 'test',
    title: _title,
    genres: const ['Комедия', 'Романтика'],
    filters: const [CatalogFilter(label: 'Комедия', path: '/anime/comedy/')],
    isOngoing: true,
    isFavorite: false,
    year: '2026',
    seriesInfo: '14 серий',
    voiceover: 'Озвучивание: AniStar',
    description: List.filled(8, 'История о семье, дружбе и неожиданных приключениях.').join(' '),
  ),
  episodes: const [
    AnimeEpisode(number: 1, title: 'Серия 1'),
    AnimeEpisode(number: 3, title: 'Длинное название третьей серии'),
    AnimeEpisode(number: 5, title: 'Серия 5'),
  ],
);

void main() {
  testWidgets('short mobile landscape can scroll to an episode', (tester) async {
    await pumpMobileApp(
      tester,
      const AnimeScreen(animeId: 1, slug: 'test', fallbackTitle: _title, onEpisodeTap: _ignoreEpisode),
      size: const Size(844, 390),
      wrapInScaffold: false,
      overrides: [
        animeRepositoryProvider.overrideWithValue(
          FakeAnimeScreenRepository(load: (_, _) async => Result.success(_data)),
        ),
      ],
    );
    await tester.pumpAndSettle();
    final episode = find.byKey(const ValueKey('mobile-episode-1'));
    await tester.scrollUntilVisible(episode, 150, scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    expect(episode.hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mobile anime pull keeps the displayed episodes and disclosure on error', (tester) async {
    var calls = 0;
    var pending = Completer<Result<AnimeScreenData, Failure>>();
    await pumpMobileApp(
      tester,
      const AnimeScreen(animeId: 1, slug: 'test', fallbackTitle: _title, onEpisodeTap: _ignoreEpisode),
      wrapInScaffold: false,
      overrides: [
        animeRepositoryProvider.overrideWithValue(
          FakeAnimeScreenRepository(
            load: (_, _) {
              calls++;

              return calls == 1 ? Future.value(Result.success(_data)) : pending.future;
            },
          ),
        ),
      ],
    );
    await tester.pumpAndSettle();
    final content = find.byType(MobileAnimeContent);
    final scroll = find.descendant(of: content, matching: find.byType(ListView));
    await tester.tap(find.text('Подробнее'));
    await tester.pumpAndSettle();
    final original = tester.widget<MobileAnimeContent>(content);
    final snapshots = ProviderScope.containerOf(tester.element(content)).read(animeKnownEpisodesProvider);
    expect(snapshots.available(1, 'test').map((episode) => episode.number), [5, 3, 1]);
    expect(original.expanded, isTrue);
    final position = tester.state<ScrollableState>(find.byType(Scrollable).first).position;
    await _pullAnime(tester, scroll);
    expect(calls, 2);
    expect(snapshots.available(1, 'test'), isEmpty);
    expect(find.byType(RefreshProgressIndicator), findsOneWidget);
    expect(tester.widget<MobileAnimeContent>(content).data, same(original.data));
    await _pullAnime(tester, scroll);
    final activeRefresh = tester.widget<MobileAnimeContent>(content).onRefresh();
    expect(tester.widget<MobileAnimeContent>(content).onRefresh(), same(activeRefresh));
    expect(calls, 2, reason: 'only one request can be in flight');
    position.jumpTo(120);
    await tester.pump();
    expect(position.pixels, 120);
    pending.complete(const Result.failure(UnknownFailure()));
    await tester.pumpAndSettle();
    expect(find.byType(RefreshProgressIndicator), findsNothing);
    expect(find.textContaining('Не удалось обновить аниме.'), findsOneWidget);
    expect(snapshots.available(1, 'test'), isEmpty);
    expect(tester.widget<MobileAnimeContent>(content).data, same(original.data));
    expect(tester.widget<MobileAnimeContent>(content).expanded, isTrue);
    expect(position.pixels, 120);
    position.jumpTo(0);
    await tester.pump();
    pending = Completer<Result<AnimeScreenData, Failure>>();
    await _pullAnime(tester, scroll);
    pending.complete(
      Result.success(
        AnimeScreenData(
          details: _data.details,
          episodes: [
            ..._data.episodes,
            const AnimeEpisode(number: 7, title: 'Новая серия'),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(calls, 3);
    expect(snapshots.available(1, 'test').map((episode) => episode.number), [7, 5, 3, 1]);
    expect(tester.widget<MobileAnimeContent>(content).episodes.first.number, 7);
    expect(tester.widget<MobileAnimeContent>(content).expanded, isTrue);
    expect(position.pixels, 0);
    // Dismissal is checked independently after failure and success.
    expect(find.byType(RefreshProgressIndicator), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mobile anime pull refresh on a short landscape list keeps disclosure usable', (tester) async {
    var calls = 0;
    final pending = Completer<Result<AnimeScreenData, Failure>>();
    final data = AnimeScreenData(
      details: _data.details,
      episodes: const [AnimeEpisode(number: 1, title: 'Серия 1')],
    );
    await pumpMobileApp(
      tester,
      const AnimeScreen(animeId: 1, slug: 'test', fallbackTitle: _title, onEpisodeTap: _ignoreEpisode),
      size: const Size(844, 390),
      textScale: 2,
      wrapInScaffold: false,
      overrides: [
        animeRepositoryProvider.overrideWithValue(
          FakeAnimeScreenRepository(
            load: (_, _) {
              calls++;

              return calls == 1 ? Future.value(Result.success(data)) : pending.future;
            },
          ),
        ),
      ],
    );
    await tester.pumpAndSettle();
    await _pullAnime(tester, find.byType(ListView));
    expect(calls, 2);
    expect(find.text('Подробнее').hitTestable(), findsOneWidget);
    pending.complete(Result.success(data));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('leaving mobile anime during pull ignores late success', (tester) async {
    var calls = 0;
    final pending = Completer<Result<AnimeScreenData, Failure>>();
    await pumpMobileApp(
      tester,
      const AnimeScreen(animeId: 1, slug: 'test', fallbackTitle: _title, onEpisodeTap: _ignoreEpisode),
      wrapInScaffold: false,
      overrides: [
        animeRepositoryProvider.overrideWithValue(
          FakeAnimeScreenRepository(
            load: (_, _) {
              calls++;

              return calls == 1 ? Future.value(Result.success(_data)) : pending.future;
            },
          ),
        ),
      ],
    );
    await tester.pumpAndSettle();
    await _pullAnime(tester, find.byType(ListView));
    expect(calls, 2);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    pending.complete(Result.success(_data));
    await tester.pumpAndSettle();
    expect(find.byType(AnimeScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mobile error retry recovers to a playable episode list', (tester) async {
    var calls = 0;
    await pumpMobileApp(
      tester,
      const AnimeScreen(animeId: 1, slug: 'test', fallbackTitle: 'Тест', onEpisodeTap: _ignoreEpisode),
      wrapInScaffold: false,
      overrides: [
        animeRepositoryProvider.overrideWithValue(
          FakeAnimeScreenRepository(
            load: (_, _) async {
              calls++;
              if (calls == 1) {
                throw StateError('secret');
              }

              return Result.success(_data);
            },
          ),
        ),
      ],
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('secret'), findsNothing);
    await tester.tap(find.text('Повторить'));
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(find.text(_title), findsOneWidget);
    expect(find.byKey(const ValueKey('mobile-episode-5')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mobile episode touch, disclosed filter and semantic episode activation', (tester) async {
    int? opened;
    CatalogFilter? selected;
    final semantics = tester.ensureSemantics();
    await pumpMobileApp(
      tester,
      AnimeScreen(
        animeId: 1,
        slug: 'test',
        fallbackTitle: _title,
        onEpisodeTap: (episode) => opened = episode.number,
        onFilterTap: (filter) => selected = filter,
      ),
      wrapInScaffold: false,
      overrides: [
        animeRepositoryProvider.overrideWithValue(
          FakeAnimeScreenRepository(load: (_, _) async => Result.success(_data)),
        ),
      ],
    );
    await tester.pumpAndSettle();
    final content = find.byType(MobileAnimeContent);
    expect(tester.widget<MobileAnimeContent>(content).filterActions, isNull);
    final scrollable = find.descendant(of: content, matching: find.byType(Scrollable));
    final third = find.byKey(const ValueKey('mobile-episode-3'));
    await tester.scrollUntilVisible(third, 150, scrollable: scrollable);
    await tester.ensureVisible(third);
    await tester.tap(third);
    expect(opened, 3);
    final more = find.text('Подробнее');
    await tester.scrollUntilVisible(more, -150, scrollable: scrollable);
    await tester.tap(more);
    await tester.pumpAndSettle();
    expect(more, findsOneWidget);
    expect(tester.widget<MobileAnimeContent>(content).expanded, isTrue);
    final chip = find.text('Комедия');
    await tester.scrollUntilVisible(chip, 150, scrollable: scrollable);
    await tester.ensureVisible(chip);
    await tester.tap(chip);
    expect(selected?.path, '/anime/comedy/');
    final episode = find.byKey(const ValueKey('mobile-episode-5'));
    await tester.scrollUntilVisible(episode, 200, scrollable: scrollable);
    await tester.ensureVisible(episode);
    await tester.pumpAndSettle();
    final node = tester.semantics.simulatedAccessibilityTraversal().singleWhere((node) => node.label == 'Серия 5');
    expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    node.owner?.performAction(node.id, SemanticsAction.tap);
    await tester.pump();
    expect(opened, 5);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('mobile parts retain full labels and distinct touch targets after rotation', (tester) async {
    const current = 'Первая часть с длинным полным названием';
    const other = 'Вторая часть с длинным полным названием';
    const parts = [
      AnimePart(label: current, uri: null, id: 1, slug: 'test'),
      AnimePart(label: other, uri: null, id: 2, slug: 'other'),
    ];
    final data = AnimeScreenData(
      details: AnimeDetails(id: 1, slug: 'test', title: 'Аниме', genres: const [], isOngoing: false, parts: parts),
      episodes: _data.episodes,
    );
    final opened = <int?>[];
    await pumpMobileApp(
      tester,
      AnimeScreen(
        animeId: 1,
        slug: 'test',
        fallbackTitle: 'Аниме',
        onEpisodeTap: _ignoreEpisode,
        onPartTap: (part) => opened.add(part.id),
      ),
      wrapInScaffold: false,
      textScale: 2,
      overrides: [
        animeRepositoryProvider.overrideWithValue(
          FakeAnimeScreenRepository(load: (_, _) async => Result.success(data)),
        ),
      ],
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Подробнее'));
    await tester.pumpAndSettle();
    final scrollable = find.byType(Scrollable);
    final currentLabel = find.text('$current, Открыто');
    final otherLabel = find.text(other);
    await tester.scrollUntilVisible(find.text('Смотреть также'), 140, scrollable: scrollable);
    await tester.pumpAndSettle();
    final currentTarget = find.ancestor(of: currentLabel, matching: find.byType(TvFocusable));
    final otherTarget = find.ancestor(of: otherLabel, matching: find.byType(TvFocusable));
    final currentRect = tester.getRect(currentTarget);
    final otherRect = tester.getRect(otherTarget);
    expect(currentTarget.hitTestable(), findsOneWidget);
    expect(otherTarget.hitTestable(), findsOneWidget);
    expect(currentRect.height, greaterThanOrEqualTo(48));
    expect(otherRect.height, greaterThanOrEqualTo(48));
    expect(otherRect.top - currentRect.bottom, 8);
    expect(tester.getSize(otherLabel).height, greaterThan(40));
    expect(tester.widget<Text>(otherLabel).maxLines, isNull);
    expect(find.descendant(of: otherTarget, matching: find.byType(AppIcon)), findsNothing);
    await tester.tapAt(currentRect.bottomCenter + const Offset(0, -4));
    await tester.pumpAndSettle();
    expect(opened, isEmpty);
    expect(tester.widget<TvFocusable>(currentTarget).focusNode?.hasFocus, isTrue);
    final otherEdge = tester.getRect(otherTarget).topCenter + const Offset(0, 4);
    await tester.tapAt(otherEdge);
    await tester.pumpAndSettle();
    expect(opened, [2]);

    final position = tester.state<ScrollableState>(scrollable).position;
    final offset = position.pixels;
    tester.view.physicalSize = const Size(844, 390);
    await tester.pumpAndSettle();
    expect(tester.widget<MobileAnimeContent>(find.byType(MobileAnimeContent)).expanded, isTrue);
    expect(tester.state<ScrollableState>(scrollable).position, same(position));
    expect(position.pixels, closeTo(offset, 1));
    expect(tester.takeException(), isNull);
  });

  for (final (name, size) in [
    ('narrow', const Size(320, 740)),
    ('phone', const Size(390, 844)),
    ('landscape', const Size(844, 390)),
  ]) {
    for (final scale in [1.0, 2.0]) {
      for (final loading in [true, false]) {
        testWidgets('mobile anime $name scale $scale loading $loading', (tester) async {
          final pending = Completer<Result<AnimeScreenData, Failure>>();
          await pumpMobileApp(
            tester,
            MediaQuery(
              data: MediaQueryData(size: size, disableAnimations: true, textScaler: TextScaler.linear(scale)),
              child: const AnimeScreen(
                animeId: 1,
                slug: 'test',
                fallbackTitle: _title,
                onEpisodeTap: _ignoreEpisode,
                onFilterTap: _ignoreFilter,
              ),
            ),
            size: size,
            wrapInScaffold: false,
            overrides: [
              animeRepositoryProvider.overrideWithValue(
                FakeAnimeScreenRepository(
                  load: (_, _) => loading ? pending.future : Future.value(Result.success(_data)),
                ),
              ),
            ],
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          if (!loading && name == 'landscape' && scale > 1) {
            expect(find.text('Подробнее').hitTestable(), findsOneWidget);
          }
          await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile(
              'goldens/mobile_anime_${loading ? 'loading' : 'ready'}_$name${scale == 1 ? '' : '_scaled'}.png',
            ),
          );
          if (!loading) {
            final episode = find.byKey(const ValueKey('mobile-episode-5'));
            await tester.scrollUntilVisible(episode, 200, scrollable: find.byType(Scrollable).first);
            await tester.pumpAndSettle();
            expect(episode.hitTestable(), findsOneWidget);
            expect(tester.takeException(), isNull);
          }
        }, tags: ['golden']);
      }
    }
  }
}

// Layout tests render actions without navigating.
// ignore: no-empty-block
void _ignoreEpisode(AnimeEpisode episode) {
  // Layout and refresh tests keep the anime route mounted.
}

// Goldens do not open filter routes.
// ignore: no-empty-block
void _ignoreFilter(CatalogFilter filter) {
  // Goldens only need the filter action rendered.
}

Future<void> _pullAnime(WidgetTester tester, Finder scroll) async {
  await tester.drag(scroll, const Offset(0, 350));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 250));
  await tester.pump();
}
