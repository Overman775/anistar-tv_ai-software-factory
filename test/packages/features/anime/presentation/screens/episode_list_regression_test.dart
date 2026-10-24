import 'dart:async';

import 'package:anistar_tv/packages/features/anime/anime_providers.dart';
import 'package:anistar_tv/packages/features/anime/domain/models/anime_details.dart';
import 'package:anistar_tv/packages/features/anime/domain/models/anime_episode.dart';
import 'package:anistar_tv/packages/features/anime/domain/models/anime_screen_data.dart';
import 'package:anistar_tv/packages/features/anime/presentation/screens/anime_screen.dart';
import 'package:anistar_tv/packages/features/anime/presentation/widgets/episode_card.dart';
import 'package:anistar_tv/packages/features/anime/presentation/widgets/mobile_anime_content.dart';
import 'package:core/data.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';

import '../../../../../mocks/features/anime/fake_anime_screen_repository.dart';
import '../../../../../support/test_app.dart';

// Repeated reads observe layout and focus after different asynchronous transitions.

const _longTitle = 'Очень длинное собственное название серии о путешествии друзей через незнакомые города';

void main() {
  for (final size in [const Size(640, 360), compactTvSize]) {
    for (final scale in [1.0, 1.3, 2.0]) {
      testWidgets('actual TV episode grid has no layout error at $size text $scale', (tester) async {
        final pending = Completer<Result<AnimeScreenData, Failure>>();
        await pumpTvApp(
          tester,
          MediaQuery(
            data: MediaQueryData(size: size, textScaler: TextScaler.linear(scale), disableAnimations: true),
            child: const AnimeScreen(animeId: 1, slug: 'test', fallbackTitle: 'Аниме', onEpisodeTap: _unexpected),
          ),
          size: size,
          wrapInScaffold: false,
          overrides: [
            animeRepositoryProvider.overrideWithValue(FakeAnimeScreenRepository(load: (_, _) => pending.future)),
          ],
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'loading layout');
        final position = tester.state<ScrollableState>(find.byType(Scrollable).first).position;
        final extent = position.maxScrollExtent;
        position.jumpTo(extent);
        await tester.pumpAndSettle();
        pending.complete(Result.success(_data(8)));
        await tester.pumpAndSettle();
        await _key(tester, LogicalKeyboardKey.arrowDown);
        expect(find.byType(EpisodeCard), findsWidgets);
        expect(tester.takeException(), isNull, reason: 'actual production episode grid must fit the full caption');
      });
    }
  }

  for (final mobile in [false, true]) {
    for (final title in ['Серия 7', '  сЕрИя\t 7 \n', _longTitle, 'Серия 7: начало', 'Серия 8', '7']) {
      testWidgets('${mobile ? 'mobile' : 'TV'} preserves only descriptive title: $title', (tester) async {
        final semantics = tester.ensureSemantics();
        var actions = 0;
        final episode = AnimeEpisode(number: 7, title: title, isWatched: true);
        final child = mobile
            ? EpisodeCard(episode: episode, episodeHeight: 92, onTap: () => actions++)
            : SizedBox(
                width: 360,
                height: 220,
                child: EpisodeCard(episode: episode, onTap: () => actions++),
              );
        if (mobile) {
          await pumpMobileApp(tester, child);
        } else {
          await pumpTvApp(tester, child);
        }
        await tester.pumpAndSettle();
        final template = title == 'Серия 7' || title == '  сЕрИя\t 7 \n';
        final tile = find.byType(EpisodeCard);
        final texts = tester.widgetList<Text>(find.descendant(of: tile, matching: find.byType(Text)));
        var visibleTitle = 'Серия 7';
        if (mobile) {
          visibleTitle = template ? 'Серия 7' : title;
        }
        expect(texts.map((text) => text.data), contains(visibleTitle));
        if (template) {
          expect(texts.where((text) => text.data?.toLowerCase().contains('серия') ?? false), hasLength(1));
        } else {
          expect(find.text(title), findsOneWidget);
        }
        final label = template ? 'Серия 7, просмотрена' : 'Серия 7, $title, просмотрена';
        final semanticTile = find.bySemanticsLabel(label);
        expect(semanticTile, findsOneWidget);
        final node = tester.getSemantics(semanticTile);
        expect(node.label, label);
        expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
        node.owner?.performAction(node.id, SemanticsAction.tap);
        await tester.pump();
        expect(actions, 1);
        await tester.tap(tile);
        expect(actions, 2, reason: 'each touch or semantic activation invokes the callback once');
        semantics.dispose();
      });
    }
  }

  for (final size in [const Size(640, 360), compactTvSize, wideTvSize, const Size(1920, 1080)]) {
    for (final scale in [1.0, 1.3, 2.0]) {
      testWidgets('three equal loading/ready columns at $size with text $scale', (tester) async {
        final pending = Completer<Result<AnimeScreenData, Failure>>();
        await pumpTvApp(
          tester,
          MediaQuery(
            data: MediaQueryData(size: size, textScaler: TextScaler.linear(scale), disableAnimations: true),
            child: const AnimeScreen(animeId: 1, slug: 'test', fallbackTitle: 'Аниме', onEpisodeTap: _unexpected),
          ),
          size: size,
          wrapInScaffold: false,
          overrides: [
            animeRepositoryProvider.overrideWithValue(FakeAnimeScreenRepository(load: (_, _) => pending.future)),
          ],
        );
        await tester.pumpAndSettle();
        final loadingScroll = tester.state<ScrollableState>(find.byType(Scrollable).first).position;
        final loadingEnd = loadingScroll.maxScrollExtent;
        loadingScroll.jumpTo(loadingEnd);
        await tester.pumpAndSettle();
        final loading = tester.widget<SliverGrid>(find.byType(SliverGrid)).gridDelegate;
        expect(loading, isA<SliverGridDelegateWithFixedCrossAxisCount>());
        final loadingGrid = loading as SliverGridDelegateWithFixedCrossAxisCount;
        expect(loadingGrid.crossAxisCount, 3);
        expect(find.byType(EpisodeCard), findsNothing);
        pending.complete(Result.success(_data(8)));
        await tester.pumpAndSettle();
        await _key(tester, LogicalKeyboardKey.arrowDown);
        final readyGrid = tester.widget<SliverGrid>(find.byType(SliverGrid)).gridDelegate;
        expect(readyGrid, isA<SliverGridDelegateWithFixedCrossAxisCount>());
        final ready = readyGrid as SliverGridDelegateWithFixedCrossAxisCount;
        expect(
          (ready.crossAxisCount, ready.mainAxisExtent, ready.crossAxisSpacing),
          (3, loadingGrid.mainAxisExtent, loadingGrid.crossAxisSpacing),
        );
        final cards = find.byType(EpisodeCard);
        final first = _card(8);
        final second = _card(7);
        final third = _card(6);
        final rects = [first, second, third].map(tester.getRect).toList();
        expect(rects.map((rect) => rect.top).toSet(), hasLength(1));
        expect(rects.map((rect) => rect.width), everyElement(closeTo(rects.first.width, 0.001)));
        expect(rects[0].right, lessThan(rects[1].left));
        expect(rects[1].right, lessThan(rects[2].left));
        final caption = find.descendant(of: first, matching: find.text('Серия 8'));
        final title = find.descendant(of: first, matching: find.text(_longTitle));
        expect(tester.getRect(caption).bottom, lessThan(tester.getRect(title).top));
        final context = tester.element(first);
        expect(tester.widget<Text>(title).style?.fontSize, 14);
        expect(tester.widget<Text>(caption).style?.fontSize, 18);
        expect(MediaQuery.textScalerOf(context).scale(20), closeTo(scale * 20, 0.001));
        final visited = <int>{};
        for (var row = 0; row < 3; row++) {
          visited.addAll(tester.widgetList<EpisodeCard>(cards).map((card) => card.episode.number));
          await _key(tester, LogicalKeyboardKey.arrowDown);
        }
        expect(visited, containsAll(List.generate(8, (index) => index + 1)));
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('remote follows row edges, partial last row, lazy rows and restores a route return', (tester) async {
    final opened = <int>[];
    await pumpTvApp(
      tester,
      Builder(
        builder: (context) => AnimeScreen(
          animeId: 1,
          slug: 'test',
          fallbackTitle: 'Аниме',
          onEpisodeTap: (episode) {
            opened.add(episode.number);
            unawaited(
              Navigator.of(context).push<void>(MaterialPageRoute(builder: (_) => const Scaffold(body: Text('Player')))),
            );
          },
        ),
      ),
      wrapInScaffold: false,
      overrides: [
        animeRepositoryProvider.overrideWithValue(
          FakeAnimeScreenRepository(load: (_, _) async => Result.success(_data(32))),
        ),
      ],
    );
    await tester.pumpAndSettle();
    await _key(tester, LogicalKeyboardKey.arrowDown);
    final transitions = [
      (LogicalKeyboardKey.arrowLeft, 32),
      (LogicalKeyboardKey.arrowRight, 31),
      (LogicalKeyboardKey.arrowRight, 30),
      (LogicalKeyboardKey.arrowRight, 30),
      (LogicalKeyboardKey.arrowDown, 27),
      (LogicalKeyboardKey.arrowLeft, 28),
      (LogicalKeyboardKey.arrowUp, 31),
    ];
    for (final (key, number) in transitions) {
      await _key(tester, key);
      expect(_focusedNumber(), number);
    }
    for (var row = 0; row < 10; row++) {
      await _key(tester, LogicalKeyboardKey.arrowDown);
    }
    expect(_focusedNumber(), 1);
    await _key(tester, LogicalKeyboardKey.arrowRight);
    expect(_focusedNumber(), 1, reason: 'the last incomplete row has no third cell');
    await _key(tester, LogicalKeyboardKey.arrowLeft);
    expect(_focusedNumber(), 2);
    await _key(tester, LogicalKeyboardKey.arrowDown);
    expect(_focusedNumber(), 2, reason: 'Down at the final row stays in place');
    final controller = tester.widget<CustomScrollView>(find.byType(CustomScrollView)).controller;
    final offset = controller?.offset;
    expect(offset, isPositive);
    expect(_card(2).hitTestable(), findsOneWidget);
    await _key(tester, LogicalKeyboardKey.select);
    expect(opened, [2]);
    Navigator.of(tester.element(find.text('Player'))).pop();
    await tester.pumpAndSettle();
    expect((_focusedNumber(), controller?.offset), (2, offset));
    expect(tester.takeException(), isNull);
  });

  testWidgets('episode focus only moves on KeyDown or KeyRepeat, never KeyUp', (tester) async {
    await pumpTvApp(
      tester,
      const AnimeScreen(animeId: 1, slug: 'test', fallbackTitle: 'Аниме', onEpisodeTap: _unexpected),
      wrapInScaffold: false,
      overrides: [
        animeRepositoryProvider.overrideWithValue(
          FakeAnimeScreenRepository(load: (_, _) async => Result.success(_data(8))),
        ),
      ],
    );
    await tester.pumpAndSettle();
    await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(_focusedNumber(), isNull);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(_focusedNumber(), 8);
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(_focusedNumber(), 5);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(_focusedNumber(), 5);
  });

  testWidgets('a removed focused episode leaves an available action and an empty list can reload', (tester) async {
    final repository = FakeAnimeScreenRepository(
      load: (_, slug) async => Result.success(_data(slug == 'full' ? 8 : 0)),
    );
    final overrides = [animeRepositoryProvider.overrideWithValue(repository)];
    AnimeScreen screen(String slug) =>
        AnimeScreen(animeId: 1, slug: slug, fallbackTitle: 'Аниме', onEpisodeTap: _unexpected);
    await pumpTvApp(tester, screen('full'), overrides: overrides, wrapInScaffold: false);
    await tester.pumpAndSettle();
    await _key(tester, LogicalKeyboardKey.arrowDown);
    expect(_focusedNumber(), 8);
    await pumpTvApp(tester, screen('empty'), overrides: overrides, wrapInScaffold: false);
    await tester.pumpAndSettle();
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'Обновить серии');
    expect(find.byType(EpisodeCard), findsNothing);
    await _key(tester, LogicalKeyboardKey.arrowDown);
    expect(find.widgetWithText(AppButton, 'Обновить серии').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('rotation preserves mobile list state and semantic activation context', (tester) async {
    final semantics = tester.ensureSemantics();
    final opened = <int>[];
    var loads = 0;
    await pumpMobileApp(
      tester,
      AnimeScreen(
        animeId: 1,
        slug: 'test',
        fallbackTitle: 'Аниме',
        onEpisodeTap: (episode) => opened.add(episode.number),
      ),
      wrapInScaffold: false,
      overrides: [
        animeRepositoryProvider.overrideWithValue(
          FakeAnimeScreenRepository(
            load: (_, _) async {
              loads++;

              return Result.success(_data(32));
            },
          ),
        ),
      ],
    );
    await tester.pumpAndSettle();
    final content = find.byType(MobileAnimeContent);
    final state = tester.state(content);
    final row = find.byKey(const ValueKey('mobile-episode-20'));
    final list = find.descendant(of: content, matching: find.byType(Scrollable));
    expect(list, findsOneWidget);
    await tester.scrollUntilVisible(row, 200, scrollable: list);
    await tester.pumpAndSettle();
    final controller = tester.widget<MobileAnimeContent>(content).controller;
    final offset = controller.offset;
    tester.view.physicalSize = const Size(844, 390);
    await tester.pumpAndSettle();
    expect(tester.state(content), same(state));
    expect(controller.offset, offset);
    expect(loads, 1);
    expect(AppLayoutScope.isTvOf(tester.element(content)), isFalse);
    await tester.scrollUntilVisible(row, -100, scrollable: list);
    await tester.pumpAndSettle();
    final node = tester.semantics.simulatedAccessibilityTraversal().singleWhere((node) => node.label == 'Серия 20');
    node.owner?.performAction(node.id, SemanticsAction.tap);
    await tester.pump();
    expect(opened, [20]);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  for (final size in [const Size(320, 740), const Size(390, 844), const Size(844, 390)]) {
    for (final scale in [1.0, 1.3, 2.0]) {
      testWidgets('mobile rows grow without columns at $size with text $scale', (tester) async {
        await pumpMobileApp(
          tester,
          const AnimeScreen(animeId: 1, slug: 'test', fallbackTitle: 'Аниме', onEpisodeTap: _unexpected),
          size: size,
          textScale: scale,
          wrapInScaffold: false,
          overrides: [
            animeRepositoryProvider.overrideWithValue(
              FakeAnimeScreenRepository(load: (_, _) async => Result.success(_data(8))),
            ),
          ],
        );
        await tester.pumpAndSettle();
        final content = tester.widget<MobileAnimeContent>(find.byType(MobileAnimeContent));
        expect(content.episodes.map((episode) => episode.number), [8, 7, 6, 5, 4, 3, 2, 1]);
        final heights = <double>[];
        final lefts = <double>[];
        for (final number in [8, 7, 1]) {
          final row = find.byKey(ValueKey('mobile-episode-$number'));
          await tester.scrollUntilVisible(row, 150, scrollable: find.byType(Scrollable).first);
          await tester.pumpAndSettle();
          final rect = tester.getRect(row);
          heights.add(rect.height);
          lefts.add(rect.left);
          expect(rect.width, greaterThan(size.width * 0.8));
          if (number == 8) {
            final title = find.descendant(of: row, matching: find.text(_longTitle));
            expect(tester.widget<Text>(title).style?.fontSize, 14);
            final caption = find.descendant(of: row, matching: find.text('Серия 8'));
            expect(tester.widget<Text>(caption).style?.fontSize, 15);
          }
        }
        expect(lefts.toSet(), hasLength(1));
        expect(heights.first, greaterThan(heights.last), reason: 'descriptive titles use additional row height');
        expect(find.byType(EpisodeCard), findsWidgets);
        expect(tester.takeException(), isNull);
      });
    }
  }
}

AnimeScreenData _data(int count) => AnimeScreenData(
  details: AnimeDetails(id: 1, slug: 'test', title: 'Аниме', genres: const [], isOngoing: false),
  episodes: List.generate(
    count,
    (index) => AnimeEpisode(number: index + 1, title: index == count - 1 ? _longTitle : 'Серия ${index + 1}'),
  ),
);

Finder _card(int number) =>
    find.byWidgetPredicate((widget) => widget is EpisodeCard && widget.episode.number == number);

int? _focusedNumber() =>
    FocusManager.instance.primaryFocus?.context?.findAncestorWidgetOfExactType<EpisodeCard>()?.episode.number;

Future<void> _key(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyEvent(key);
  await tester.pumpAndSettle();
}

void _unexpected(AnimeEpisode episode) => fail('Unexpected episode ${episode.number}');
