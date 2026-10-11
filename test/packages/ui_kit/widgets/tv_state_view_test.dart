// Repeated checks observe geometry and focus after asynchronous layout.
// ignore_for_file: prefer-moving-to-variable

import 'package:flutter/services.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';

import '../../../support/test_app.dart';

void main() {
  for (final size in [const Size(640, 360), const Size(390, 844)]) {
    testWidgets('long mixed-script state at 200% keeps remote recovery visible at $size', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final semantics = tester.ensureSemantics();
      var calls = 0;
      final message = List.filled(3, 'Проверьте сеть и повторите попытку. 日本語 العربية 🎬').join(' ');
      await pumpTvApp(
        tester,
        TvStateView(
          icon: Icons.cloud_off_rounded,
          title: 'Не удалось загрузить данные',
          message: message,
          actionLabel: 'Повторить',
          onAction: () => calls++,
        ),
        size: size,
      );
      await tester.pumpAndSettle();
      final button = find.widgetWithText(FilledButton, 'Повторить');
      final rect = tester.getRect(button);
      expect(rect.top, greaterThanOrEqualTo(0));
      expect(rect.bottom, lessThanOrEqualTo(size.height));
      expect(button.hitTestable(), findsOneWidget);
      final announcement = find.byWidgetPredicate(
        (widget) => widget is Semantics && widget.properties.liveRegion == true,
      );
      final data = tester.getSemantics(announcement).getSemanticsData();
      expect(data.flagsCollection.isLiveRegion, isTrue);
      expect(data.label, contains(message));
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      expect(calls, 1);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    });
  }

  testWidgets('long empty state can scroll without a recovery action', (tester) async {
    await pumpTvApp(
      tester,
      TvStateView(
        icon: Icons.playlist_remove,
        title: 'Нет данных',
        message: List.filled(15, 'Описание пустого результата 🎬').join(' '),
      ),
      size: const Size(640, 360),
    );
    await tester.pumpAndSettle();
    final scroll = find.byType(SingleChildScrollView);
    await tester.drag(scroll, const Offset(0, -240));
    await tester.pumpAndSettle();
    expect(tester.state<ScrollableState>(find.byType(Scrollable)).position.pixels, greaterThan(0));
    expect(find.byType(FilledButton), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('renders a polished state and invokes its action', (tester) async {
    var actionCalls = 0;

    await pumpTvApp(
      tester,
      TvBackdrop(
        child: TvStateView(
          icon: Icons.cloud_off_rounded,
          title: 'Каталог недоступен',
          message: 'Проверьте подключение',
          actionLabel: 'Попробовать снова',
          onAction: () => actionCalls++,
        ),
      ),
    );

    expect(find.text('Каталог недоступен'), findsOneWidget);
    expect(find.text('Проверьте подключение'), findsOneWidget);
    expect(find.byIcon(Icons.cloud_off_rounded), findsOneWidget);

    await tester.tap(find.text('Попробовать снова'));

    expect(actionCalls, 1);
  });
}
