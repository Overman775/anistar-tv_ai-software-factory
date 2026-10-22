import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';

import '../../../support/test_app.dart';

void main() {
  testWidgets('busy action blocks key and touch repeats while retaining focus', (tester) async {
    final focus = FocusNode();
    addTearDown(focus.dispose);
    final settle = tester.pumpAndSettle;
    final key = tester.sendKeyEvent;
    var calls = 0;
    var busy = false;
    late StateSetter update;
    await pumpTvApp(
      tester,
      Center(
        child: StatefulBuilder(
          builder: (_, setState) {
            update = setState;

            return AppButton(
              label: 'Смотреть',
              focusNode: focus,
              autofocus: true,
              busy: busy,
              onPressed: () => calls++,
            );
          },
        ),
      ),
    );
    await settle();
    await key(LogicalKeyboardKey.select);
    update(() => busy = true);
    await tester.pump();
    await key(LogicalKeyboardKey.select);
    await tester.tap(find.text('Смотреть'));
    expect(calls, 1);
    expect(focus.hasFocus, isTrue);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    update(() => busy = false);
    await settle();
    await key(LogicalKeyboardKey.select);
    expect(calls, 2);
  });

  testWidgets('disabled action cannot gain focus or activate', (tester) async {
    final focus = FocusNode();
    addTearDown(focus.dispose);
    var calls = 0;
    await pumpTvApp(
      tester,
      Center(
        child: AppButton(label: 'Недоступно', enabled: false, focusNode: focus, onPressed: () => calls++),
      ),
    );
    await tester.tap(find.text('Недоступно'));
    focus.requestFocus();
    await tester.pump();
    expect(focus.hasFocus, isFalse);
    expect(calls, 0);
  });

  testWidgets('large mobile text grows the button without clipping', (tester) async {
    await pumpMobileApp(
      tester,
      Center(
        child: SizedBox(
          width: 300,
          child: AppButton(label: 'Попробовать снова', onPressed: () => fail('Unexpected activation')),
        ),
      ),
      textScale: 2,
    );
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(AppButton)).height, greaterThanOrEqualTo(48));
    expect(tester.takeException(), isNull);
  });
}
