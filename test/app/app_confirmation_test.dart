import 'dart:async';

import 'package:anistar_tv/app/app_confirmation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';

import '../support/test_app.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets('$platform root exit preserves account and requires Android confirmation', (tester) async {
      var exits = 0;
      final settle = tester.pumpAndSettle;
      final sendKey = tester.sendKeyEvent;
      final rootAction = find.text('Root Back');
      final title = find.text('Выйти из приложения?');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'SystemNavigator.pop') {
          exits++;
        }

        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
      await pumpTvApp(
        tester,
        Builder(
          builder: (context) => AppButton(label: 'Root Back', onPressed: () => confirmAppExit(context)),
        ),
      );
      await tester.tap(rootAction);
      await settle();
      if (platform == TargetPlatform.iOS) {
        expect(title, findsNothing);
        expect(exits, 0);
      } else {
        expect(title, findsOneWidget);
        expect(FocusManager.instance.primaryFocus?.debugLabel, 'Отмена подтверждения');
        await sendKey(LogicalKeyboardKey.select);
        await settle();
        expect(exits, 0);
        expect(title, findsNothing);
        await tester.tap(rootAction);
        await settle();
        await sendKey(LogicalKeyboardKey.arrowDown);
        await sendKey(LogicalKeyboardKey.select);
        await settle();
        expect(exits, 1);
      }
      expect(tester.takeException(), isNull);
    }, variant: TargetPlatformVariant({platform}));
  }

  testWidgets('large-text confirmation can scroll to message and both actions without confirming on Back', (
    tester,
  ) async {
    bool? result;
    final settle = tester.pumpAndSettle;
    final sendKey = tester.sendKeyEvent;
    await pumpMobileApp(
      tester,
      Builder(
        builder: (context) => AppButton(
          label: 'Открыть',
          onPressed: () {
            unawaited(
              showAppConfirmation(
                context,
                title: 'Выйти?',
                message: 'Аккаунт будет сохранён. Вы сможете продолжить после следующего запуска.',
                confirmLabel: 'Подтвердить',
              ).then((value) {
                result = value;
              }),
            );
          },
        ),
      ),
      size: const Size(320, 568),
      textScale: 2,
    );
    await tester.tap(find.text('Открыть'));
    await settle();
    final cancel = find.byKey(const ValueKey('confirmation-cancel'));
    expect(cancel.hitTestable(), findsOneWidget);
    await sendKey(LogicalKeyboardKey.arrowUp);
    await settle();
    final list = tester.state<ScrollableState>(find.byType(Scrollable).last).position;
    expect(list.pixels, lessThan(list.maxScrollExtent));
    await tester.binding.handlePopRoute();
    await settle();
    expect(result, isFalse);
    expect(tester.takeException(), isNull);
  });
}
