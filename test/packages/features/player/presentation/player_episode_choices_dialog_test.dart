import 'dart:async';

import 'package:anistar_tv/packages/features/player/domain/models/playback_episode.dart';
import 'package:anistar_tv/packages/features/player/presentation/widgets/player_episode_choices_dialog.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';

import '../../../../support/test_app.dart';

void main() {
  const selectedEpisodeLabel = 'Серия 20, Текущая серия с длинным названием, текущая, просмотрена';

  Finder selectedCard() =>
      find.byWidgetPredicate((widget) => widget is MediaCard && widget.selected && widget.label == 'Серия 20');

  List<PlaybackEpisode> episodes() => List.generate(
    32,
    (index) => PlaybackEpisode(
      number: index + 1,
      title: index == 19 ? 'Текущая серия с длинным названием' : 'Серия ${index + 1}',
      isWatched: index == 19,
    ),
  );

  Future<void> pumpChoices(
    WidgetTester tester, {
    required GoldenTextScale textScale,
    bool reducedMotion = false,
  }) async {
    final settle = tester.pumpAndSettle;
    await pumpScreenGolden(
      tester,
      Builder(
        builder: (context) => FilledButton(
          autofocus: true,
          onPressed: () => unawaited(
            showTvSideSheet<void>(
              context: context,
              builder: (context) => MediaQuery(
                data: MediaQuery.of(context).copyWith(disableAnimations: reducedMotion),
                child: PlayerEpisodeChoicesDialog(episodes: episodes(), selected: 20, watchedEpisodeNumbers: const {2}),
              ),
            ),
          ),
          child: const Text('Серии'),
        ),
      ),
      textScale: textScale,
    );
    await settle();
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await settle();
  }

  void expectSelectedCard(WidgetTester tester) {
    final selected = selectedCard();
    final card = tester.widget<MediaCard>(selected);
    expect(selected.hitTestable(), findsOneWidget);
    expect(card.variant, MediaCardVariant.episode);
    expect(card.selected, isTrue);
    expect(card.autofocus, isTrue);
    expect(card.showEpisodeTrailing, isFalse, reason: 'Episode selection must not add a Play affordance.');
    expect(card.caption, 'Текущая серия с длинным названием');
    expect(FocusManager.instance.primaryFocus?.debugLabel, selectedEpisodeLabel);
  }

  testWidgets('current long-list episode receives focus, scrolls into view and keeps metadata states distinct', (
    tester,
  ) async {
    await pumpChoices(tester, textScale: GoldenTextScale.normal);

    expectSelectedCard(tester);
    final position = tester.state<ScrollableState>(find.byType(Scrollable)).position;
    expect(position.pixels, greaterThan(0));
    expect(find.bySemanticsLabel(selectedEpisodeLabel), findsOneWidget);
    expect(tester.widget<MediaCard>(selectedCard()).imageUrl, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('episode choices golden at tv', (tester) async {
    await pumpChoices(tester, textScale: GoldenTextScale.normal);
    expectSelectedCard(tester);
    await expectScreenGolden('player_episode_choices');
  }, tags: ['golden']);

  testWidgets('late selected episode stays visible and focused after a TV window resize', (tester) async {
    await pumpChoices(tester, textScale: GoldenTextScale.normal);
    expectSelectedCard(tester);

    tester.view.physicalSize = wideTvSize;
    tester.view.devicePixelRatio = 1;
    await tester.pumpAndSettle();
    expectSelectedCard(tester);
    expect(selectedCard().hitTestable(), findsOneWidget);
    expect(tester.getRect(selectedCard()).bottom, lessThanOrEqualTo(wideTvSize.height));
    expect(tester.takeException(), isNull);

    tester.view.physicalSize = compactTvSize;
    tester.view.devicePixelRatio = 1;
    await tester.pumpAndSettle();
    expectSelectedCard(tester);
    expect(selectedCard().hitTestable(), findsOneWidget);
    expect(tester.getRect(selectedCard()).bottom, lessThanOrEqualTo(compactTvSize.height));
    expect(tester.takeException(), isNull);
  });

  testWidgets('resizing preserves focused late episode when current episode differs', (tester) async {
    await pumpChoices(tester, textScale: GoldenTextScale.normal);
    expectSelectedCard(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    final focused = FocusManager.instance.primaryFocus;
    expect(focused?.debugLabel, contains('Серия 19'));
    expect(tester.widget<MediaCard>(selectedCard()).selected, isTrue);
    tester.view.physicalSize = wideTvSize;
    await tester.pumpAndSettle();
    expect(FocusManager.instance.primaryFocus, same(focused));
    expect(find.text('Серия 19').hitTestable(), findsOneWidget);
    expect(tester.widget<MediaCard>(selectedCard()).selected, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mobile episode sheet keeps user scroll after rotation', (tester) async {
    await pumpMobileApp(
      tester,
      Builder(
        builder: (context) => FilledButton(
          onPressed: () => unawaited(
            showAppActionSheet<void>(
              context: context,
              builder: (_) =>
                  PlayerEpisodeChoicesDialog(episodes: episodes(), selected: 20, watchedEpisodeNumbers: const {}),
            ),
          ),
          child: const Text('Открыть серии'),
        ),
      ),
    );
    await tester.tap(find.text('Открыть серии'));
    await tester.pumpAndSettle();
    final list = find.descendant(of: find.byType(PlayerEpisodeChoicesDialog), matching: find.byType(Scrollable));
    final position = tester.state<ScrollableState>(list).position;
    position.jumpTo(position.maxScrollExtent * 0.7);
    await tester.pumpAndSettle();
    final offset = position.pixels;
    expect(offset, greaterThan(0));
    tester.view.physicalSize = const Size(844, 390);
    await tester.pumpAndSettle();
    expect(tester.state<ScrollableState>(list).position.pixels, closeTo(offset, 0.1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('300 episode sheet keeps distant focused row across both resize directions', (tester) async {
    final longList = List.generate(300, (index) => PlaybackEpisode(number: index + 1, title: 'Эпизод ${index + 1}'));
    int? chosenEpisode;
    await pumpTvApp(
      tester,
      Builder(
        builder: (context) => FilledButton(
          autofocus: true,
          onPressed: () => unawaited(
            showTvSideSheet<int>(
              context: context,
              builder: (_) =>
                  PlayerEpisodeChoicesDialog(episodes: longList, selected: 150, watchedEpisodeNumbers: const {}),
            ).then((value) => chosenEpisode = value),
          ),
          child: const Text('Открыть серии'),
        ),
      ),
      size: wideTvSize,
      disableAnimations: true,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    for (var index = 0; index < 30; index++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
    }
    final focus = FocusManager.instance.primaryFocus;
    expect(focus?.debugLabel, contains('Серия 120'));
    final row = find.byKey(const ValueKey('player-episode-120'));
    expect(row.hitTestable(), findsOneWidget);
    for (final size in [compactTvSize, wideTvSize]) {
      tester.view.physicalSize = size;
      await tester.pumpAndSettle();
      expect(FocusManager.instance.primaryFocus, same(focus));
      expect(row.hitTestable(), findsOneWidget);
      final bounds = tester.getRect(row);
      expect(bounds.top, greaterThanOrEqualTo(0));
      expect(bounds.bottom, lessThanOrEqualTo(size.height));
    }
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(chosenEpisode, 120);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion keeps the selected card available without focus scaling', (tester) async {
    await pumpChoices(tester, textScale: GoldenTextScale.normal, reducedMotion: true);

    expectSelectedCard(tester);
    final scale = tester.widget<AnimatedScale>(
      find.descendant(of: selectedCard(), matching: find.byType(AnimatedScale)),
    );
    expect(scale.scale, 1);
    expect(scale.duration, Duration.zero);
    expect(tester.takeException(), isNull);
  });
}
