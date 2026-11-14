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

  for (final textScale in GoldenTextScale.values) {
    testWidgets('episode choices golden at tv${textScale == GoldenTextScale.large ? ' 200%' : ''}', (tester) async {
      await pumpChoices(tester, textScale: textScale);
      expectSelectedCard(tester);
      await expectScreenGolden('player_episode_choices', textScale: textScale);
    }, tags: ['golden']);
  }

  testWidgets('200% text and reduced motion keep the selected card available without focus scaling', (tester) async {
    await pumpChoices(tester, textScale: GoldenTextScale.large, reducedMotion: true);

    expectSelectedCard(tester);
    final scale = tester.widget<AnimatedScale>(
      find.descendant(of: selectedCard(), matching: find.byType(AnimatedScale)),
    );
    expect(scale.scale, 1);
    expect(scale.duration, Duration.zero);
    expect(tester.takeException(), isNull);
  });
}
