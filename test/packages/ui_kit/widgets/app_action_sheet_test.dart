import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';

import '../../../support/test_app.dart';

void main() {
  for (final closeOnLeft in [true, false]) {
    testWidgets('TV sheet closeOnLeft=$closeOnLeft traps focus and restores its opener', (tester) async {
      final settle = tester.pumpAndSettle;
      final sheet = find.byType(TvSideSheet);
      final opener = FocusNode();
      final choice = FocusNode();
      addTearDown(opener.dispose);
      addTearDown(choice.dispose);
      await pumpTvApp(
        tester,
        Builder(
          builder: (context) => AppButton(
            label: 'Открыть',
            focusNode: opener,
            autofocus: true,
            onPressed: () => unawaited(
              showAppActionSheet<void>(
                context: context,
                builder: (_) => AppActionSheet(
                  title: 'Сортировка',
                  closeOnLeft: closeOnLeft,
                  child: AppButton(
                    label: 'Выбор',
                    focusNode: choice,
                    autofocus: true,
                    onPressed: () => fail('Unexpected activation'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await settle();
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await settle();
      expect(choice.hasFocus, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(opener.hasFocus, isFalse);
      final route = ModalRoute.of(tester.element(sheet));
      expect(route?.transitionDuration, const Duration(milliseconds: 240));
      expect(route?.reverseTransitionDuration, const Duration(milliseconds: 156));
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await settle();
      if (!closeOnLeft) {
        expect(sheet, findsOneWidget);
        await tester.binding.handlePopRoute();
        await settle();
      }
      expect(sheet, findsNothing);
      expect(opener.hasFocus, isTrue);
    });
  }

  testWidgets('wide mobile profile still uses a bottom sheet with explicit close', (tester) async {
    final settle = tester.pumpAndSettle;
    final bottomSheet = find.byType(BottomSheet);
    await pumpMobileApp(
      tester,
      Builder(
        builder: (context) => AppButton(
          label: 'Открыть',
          onPressed: () => unawaited(
            showAppActionSheet<void>(
              context: context,
              builder: (_) => const AppActionSheet(title: 'Действия', child: Text('Содержание')),
            ),
          ),
        ),
      ),
      size: wideTvSize,
      textScale: 2,
      disableAnimations: true,
    );
    await tester.tap(find.text('Открыть'));
    await settle();
    expect(find.byType(TvSideSheet), findsNothing);
    expect(bottomSheet, findsOneWidget);
    await tester.tap(find.byTooltip('Закрыть'));
    await settle();
    expect(bottomSheet, findsNothing);
    expect(tester.takeException(), isNull);
  });
}
