// Repeated pumps observe focus and route transitions.

import 'dart:async';

import 'package:anistar_tv/packages/features/player/presentation/widgets/player_choices_dialog.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';

import '../../../../support/test_app.dart';

void main() {
  testWidgets('quality choices at tv', (tester) async {
    await testScreenGolden(
      tester,
      'player_choices',
      screen: PlayerChoicesDialog<String>(
        title: 'Качество',
        choices: const ['SD 360p', 'HD 720p'],
        selected: 'HD 720p',
        label: (quality) => quality,
      ),
    );
    expect(tester.takeException(), isNull);
  }, tags: ['golden']);

  for (final scale in [1.0, 1.3]) {
    testWidgets('late episode and remote scrolling keep choices visible at $scale text', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      int? selected;
      final choices = List.generate(24, (index) => index + 1);
      await pumpTvApp(
        tester,
        Builder(
          builder: (context) => FilledButton(
            autofocus: true,
            onPressed: () => unawaited(
              showTvSideSheet<int>(
                context: context,
                builder: (_) => PlayerChoicesDialog(
                  title: 'Выберите серию',
                  choices: choices,
                  selected: 20,
                  label: (number) => 'Серия $number',
                ),
              ).then((value) => selected = value),
            ),
            child: const Text('Серии'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pumpAndSettle();
      final list = find.byType(ListView);
      final selectedTile = find.text('Серия 20');
      expect(selectedTile.hitTestable(), findsOneWidget);
      expect(tester.getRect(selectedTile).center.dy, lessThan(tester.getRect(list).bottom));
      for (var i = 0; i < 4; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
      }
      expect(find.text('Серия 24').hitTestable(), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pumpAndSettle();
      expect(selected, 24);
      expect(find.byType(PlayerChoicesDialog<int>), findsNothing);
      // Dialog dismissal returns OK to the button that opened it.
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pumpAndSettle();
      expect(find.byType(PlayerChoicesDialog<int>), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(selected, isNull);
      expect(tester.takeException(), isNull);
    });
  }
}
