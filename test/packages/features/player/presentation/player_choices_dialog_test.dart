// Repeated pumps observe focus and route transitions.
// ignore_for_file: prefer-moving-to-variable

import 'dart:async';

import 'package:anistar_tv/packages/features/player/presentation/widgets/player_choices_dialog.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';

import '../../../../support/test_app.dart';

void main() {
  testWidgets('late episode starts visible and remote scrolling keeps the next choice visible', (tester) async {
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
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(selected, isNull);
  });
}
