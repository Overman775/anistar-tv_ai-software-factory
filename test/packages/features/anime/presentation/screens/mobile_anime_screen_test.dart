import 'dart:async';

import 'package:anistar_tv/packages/features/anime/anime_providers.dart';
import 'package:anistar_tv/packages/features/anime/domain/models/anime_details.dart';
import 'package:anistar_tv/packages/features/anime/domain/models/anime_episode.dart';
import 'package:anistar_tv/packages/features/anime/domain/models/anime_screen_data.dart';
import 'package:anistar_tv/packages/features/anime/presentation/screens/anime_screen.dart';
import 'package:anistar_tv/packages/features/anime/presentation/widgets/mobile_anime_content.dart';
import 'package:anistar_tv/packages/features/catalog/domain/models/catalog_filter.dart';
import 'package:anistar_tv/packages/features/watch_history/watch_history_providers.dart';
import 'package:anistar_tv/packages/features/watch_history/watched_episodes.dart';
import 'package:core/data.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';

import '../../../../../mocks/features/anime/fake_anime_screen_repository.dart';
import '../../../../../mocks/features/fake_watched_episodes_repository.dart';
import '../../../../../support/test_app.dart';

// Widget state and layout are sampled again after each gesture and network response.

const _title = 'Пожалуйста, простите моих младших братьев / Please Forgive My Younger Brothers';
final _data = AnimeScreenData(
  details: AnimeDetails(
    id: 1,
    slug: 'test',
    title: _title,
    genres: const ['Комедия', 'Романтика'],
    filters: const [CatalogFilter(label: 'Комедия', path: '/comedy/')],
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
  testWidgets('short mobile landscape scrolls to its only actionable watch control', (tester) async {
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
    final watch = find.widgetWithText(AppButton, 'Смотреть серию 1');
    await tester.scrollUntilVisible(watch, 150, scrollable: find.byType(Scrollable).first);
    expect(watch, findsOneWidget, reason: 'only one live watch action may exist');
    expect(watch.hitTestable(), findsOneWidget, reason: 'inline watch action remains reachable by scrolling');
    expect(tester.takeException(), isNull);
  });

  for (final empty in [false, true]) {
    testWidgets('mobile anime pull reloads ${empty ? 'empty' : 'existing'} episodes and keeps content on error', (
      tester,
    ) async {
      var calls = 0;
      var pending = Completer<Result<AnimeScreenData, Failure>>();
      final initial = AnimeScreenData(details: _data.details, episodes: empty ? const [] : _data.episodes);
      await pumpMobileApp(
        tester,
        const AnimeScreen(animeId: 1, slug: 'test', fallbackTitle: _title, onEpisodeTap: _ignoreEpisode),
        wrapInScaffold: false,
        overrides: [
          animeRepositoryProvider.overrideWithValue(
            FakeAnimeScreenRepository(
              load: (_, _) {
                calls++;

                return calls == 1 ? Future.value(Result.success(initial)) : pending.future;
              },
            ),
          ),
        ],
      );
      await tester.pumpAndSettle();
      final content = find.byType(MobileAnimeContent);
      final scroll = find.descendant(of: content, matching: find.byType(ListView));
      final originalContent = tester.state(content);
      await _pullAnime(tester, scroll);
      expect(calls, 2);
      expect(find.byType(RefreshProgressIndicator), findsOneWidget);
      expect(tester.widget<MobileAnimeContent>(content).episodes.length, empty ? 0 : 3);
      await _pullAnime(tester, scroll);
      expect(calls, 2, reason: 'only one request can be in flight');
      pending.complete(const Result.failure(UnknownFailure()));
      await tester.pumpAndSettle();
      expect(find.byType(RefreshProgressIndicator), findsNothing);
      expect(find.textContaining('Не удалось обновить аниме.'), findsOneWidget);
      expect(tester.widget<MobileAnimeContent>(content).data, same(initial));
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
      expect(tester.widget<MobileAnimeContent>(content).episodes.first.number, 7);
      expect(tester.state(content), same(originalContent), reason: 'description and scroll state survive refresh');
      // Dismissal is checked independently after failure and success.
      expect(find.byType(RefreshProgressIndicator), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('mobile anime pull refresh on a short landscape list leaves pinned watch action usable', (tester) async {
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
    expect(find.widgetWithText(AppButton, 'Смотреть серию 1').hitTestable(), findsOneWidget);
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

  testWidgets('mobile error retry recovers to an empty episode list', (tester) async {
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

              return Result.success(
                AnimeScreenData(
                  details: AnimeDetails(id: 1, slug: 'test', title: 'Тест', genres: [], isOngoing: false),
                  episodes: [],
                ),
              );
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
    final reload = find.text('Обновить серии');
    await tester.ensureVisible(reload);
    await tester.pumpAndSettle();
    expect(reload.hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mobile watch action respects history, filters tap and description expands', (tester) async {
    final history = FakeWatchedEpisodesRepository()..watched[1] = {1};
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
        watchHistoryAccountProvider.overrideWithValue('tester'),
        watchedEpisodesRepositoryProvider.overrideWithValue(history),
        animeRepositoryProvider.overrideWithValue(
          FakeAnimeScreenRepository(load: (_, _) async => Result.success(_data)),
        ),
      ],
    );
    await tester.pumpAndSettle();
    final content = find.byType(MobileAnimeContent);
    expect(tester.widget<MobileAnimeContent>(content).filterActions, isNotNull);
    final scrollable = find.descendant(of: content, matching: find.byType(Scrollable));
    void expectContentScrollable() => expect(scrollable, findsOneWidget);

    expectContentScrollable();
    final play = find.widgetWithText(AppButton, 'Смотреть серию 3');
    await tester.ensureVisible(play);
    await tester.tap(play);
    expect(opened, 3);
    expectContentScrollable();
    final chip = find.text('Комедия');
    await tester.scrollUntilVisible(chip, -150, scrollable: scrollable);
    await tester.ensureVisible(chip);
    expect(chip.hitTestable(), findsOneWidget);
    await tester.tap(chip);
    expect(selected?.path, '/comedy/');
    final more = find.text('Подробнее');
    await tester.drag(scrollable, const Offset(0, -250));
    await tester.pumpAndSettle();
    expect(more.hitTestable(), findsOneWidget);
    await tester.tap(more);
    await tester.pump();
    expect(find.text('Свернуть описание'), findsOneWidget);
    final episode = find.byKey(const ValueKey('mobile-episode-5'));
    await tester.scrollUntilVisible(episode, -200, scrollable: scrollable);
    await tester.ensureVisible(episode);
    final node = tester.semantics.simulatedAccessibilityTraversal().singleWhere((node) => node.label == 'Серия 5');
    expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    node.owner?.performAction(node.id, SemanticsAction.tap);
    await tester.pump();
    expect(opened, 5);
    expect(tester.takeException(), isNull);
    semantics.dispose();
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
            expect(find.widgetWithText(AppButton, 'Смотреть серию 1').hitTestable(), findsOneWidget);
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
