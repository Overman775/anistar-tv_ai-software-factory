import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ui_kit/ui_kit.dart';

void main() {
  testWidgets('activates once from the TV select key and exposes focus semantics', (tester) async {
    var calls = 0;
    final view = tester.view;
    view
      ..physicalSize = const Size(1280, 720)
      ..devicePixelRatio = 1;
    addTearDown(view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: TvFocusable(
            autofocus: true,
            semanticLabel: 'Открыть аниме',
            onPressed: () => calls++,
            builder: (_, focused) => Text(focused ? 'В фокусе' : 'Без фокуса'),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.select);

    expect(calls, 1);
    expect(find.text('В фокусе'), findsOneWidget);
  });
}
