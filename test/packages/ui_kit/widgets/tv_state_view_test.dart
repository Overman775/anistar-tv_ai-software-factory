// Repeated checks observe geometry and focus after asynchronous layout.

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
      final button = find.widgetWithText(AppButton, 'Повторить');
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
    expect(find.byType(AppButton), findsNothing);
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
    expect(find.byType(AppIcon), findsNWidgets(2));

    await tester.tap(find.text('Попробовать снова'));

    expect(actionCalls, 1);
  });

  testWidgets('scaled compact recovery can reveal its header with Up and return to retry', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final settle = tester.pumpAndSettle;
    final key = tester.sendKeyEvent;
    var calls = 0;
    await pumpTvApp(
      tester,
      TvBackdrop(
        child: TvStateView(
          icon: Icons.cloud_off_rounded,
          title: 'Каталог недоступен',
          message: 'Не удалось получить данные AniStar. Проверьте подключение к интернету и повторите загрузку. Ваши изменения в аккаунте сохраняются на сайте.',
          actionLabel: 'Повторить',
          onAction: () => calls++,
        ),
      ),
    );
    await settle();
    final scroll = tester.state<ScrollableState>(find.byType(Scrollable)).position;
    final initiallyScrolled = scroll.pixels;
    for (var press = 0; press < 4; press++) {
      await key(LogicalKeyboardKey.arrowUp);
      await settle();
    }
    expect(initiallyScrolled, greaterThan(0));
    expect(scroll.pixels, lessThan(initiallyScrolled));
    expect(tester.getRect(find.text('Каталог недоступен')).top, greaterThanOrEqualTo(0));
    for (var press = 0; press < 4; press++) {
      await key(LogicalKeyboardKey.arrowDown);
      await settle();
    }
    expect(find.widgetWithText(AppButton, 'Повторить').hitTestable(), findsOneWidget);
    await key(LogicalKeyboardKey.select);
    expect(calls, 1);
    expect(tester.takeException(), isNull);
  });
}
