import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';

import '../../../support/test_app.dart';

void main() {
  testWidgets('activates once from the TV select key and exposes focus semantics', (tester) async {
    var calls = 0;
    await pumpTvApp(
      tester,
      TvFocusable(
        autofocus: true,
        semanticLabel: 'Открыть аниме',
        onPressed: () => calls++,
        builder: (_, focused) => Text(focused ? 'В фокусе' : 'Без фокуса'),
      ),
      size: wideTvSize,
    );
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.select);

    expect(calls, 1);
    expect(find.text('В фокусе'), findsOneWidget);
  });

  testWidgets('held OK and repeats open only the long action after release', (tester) async {
    var opened = 0;
    var menus = 0;
    await pumpTvApp(
      tester,
      TvFocusable(
        autofocus: true,
        onPressed: () => opened++,
        onLongPressed: () => menus++,
        builder: (_, focused) => const Text('Карточка'),
      ),
    );
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.select);
    await tester.pump(const Duration(milliseconds: 700));
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.select);
    expect(menus, 0);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.select);
    expect(menus, 1);
    expect(opened, 0);
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    expect(opened, 1);
  });

  testWidgets('touch hold has one action and disposal cancels the remote timer', (tester) async {
    var opened = 0;
    var menus = 0;
    await pumpTvApp(
      tester,
      TvFocusable(
        autofocus: true,
        onPressed: () => opened++,
        onLongPressed: () => menus++,
        builder: (_, focused) => const Text('Карточка'),
      ),
    );
    await tester.pump();
    await tester.longPress(find.text('Карточка'));
    expect(menus, 1);
    expect(opened, 0);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.select);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 700));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.select);
    // Disposal must not trigger another menu.
    expect(menus, 1);
  });

  testWidgets('losing focus cancels a pending held OK without opening either action', (tester) async {
    var calls = 0;
    await pumpTvApp(
      tester,
      TvFocusable(
        autofocus: true,
        onPressed: () => calls++,
        onLongPressed: () => calls++,
        builder: (_, focused) => const Text('Карточка'),
      ),
    );
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.select);
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump(const Duration(milliseconds: 700));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.select);
    expect(calls, 0);
  });
}
