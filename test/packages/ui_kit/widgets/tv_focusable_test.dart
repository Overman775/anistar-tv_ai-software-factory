// Separate key events and assertions verify each phase of the same hold.
// ignore_for_file: prefer-moving-to-variable, avoid-duplicate-test-assertions

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

  testWidgets('held OK opens the long action before release, only once', (tester) async {
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
    expect(menus, 1);
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.select);
    expect(menus, 1);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.select);
    expect(menus, 1);
    expect(opened, 0);
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    expect(opened, 1);
  });

  testWidgets('touch hold opens before release and disposal cancels pending OK', (tester) async {
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
    final gesture = await tester.startGesture(tester.getCenter(find.text('Карточка')));
    await tester.pump(const Duration(seconds: 1));
    expect(menus, 1);
    expect(opened, 0);
    await gesture.up();
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

  testWidgets('pointer cancellation clears pressed state without activation', (tester) async {
    var calls = 0;
    TvFocusState? state;
    await pumpTvApp(
      tester,
      Center(
        child: TvFocusable(
          onPressed: () => calls++,
          stateBuilder: (_, value) {
            state = value;

            return const SizedBox(width: 200, height: 100, child: Text('Нажать'));
          },
        ),
      ),
    );
    final gesture = await tester.startGesture(tester.getCenter(find.text('Нажать')));
    await tester.pump();
    expect(state?.pressed, isTrue);
    await gesture.cancel();
    await tester.pump();
    expect(state?.pressed, isFalse);
    expect(calls, 0);
  });

  testWidgets('first repeat consumes the held key tail after focus moves to a menu', (tester) async {
    final card = FocusNode();
    final menu = FocusNode();
    addTearDown(card.dispose);
    addTearDown(menu.dispose);
    var opens = 0;
    var activations = 0;
    await pumpTvApp(
      tester,
      Column(
        children: [
          TvFocusable(
            focusNode: card,
            autofocus: true,
            onPressed: () => fail('Unexpected short action'),
            onLongPressed: () {
              opens++;
              menu.requestFocus();
            },
            builder: (_, focused) => const Text('Карточка'),
          ),
          TvFocusable(focusNode: menu, onPressed: () => activations++, builder: (_, focused) => const Text('Меню')),
        ],
      ),
    );
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.select);
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.select);
    await tester.pump();
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.select);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.select);
    expect(opens, 1);
    expect(menu.hasFocus, isTrue);
    expect(activations, 0);
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    expect(activations, 1);
  });
}
