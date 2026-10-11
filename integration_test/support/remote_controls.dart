// Each pump commits a separate remote focus transition.
// ignore_for_file: prefer-moving-to-variable

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';

import 'e2e_harness.dart';

/// Navigate the visible player menu, without activating controls by touch.
abstract final class RemoteControls {
  static Future<void> openQuality(WidgetTester tester) => _open(tester, 'Качество');

  static Future<void> openEpisodes(WidgetTester tester) => _open(tester, 'Серии');

  static Future<void> nextEpisode(WidgetTester tester) => _open(tester, 'Следующая серия');

  static Future<void> previousEpisode(WidgetTester tester) => _open(tester, 'Предыдущая серия');

  static Future<void> backToEpisodes(WidgetTester tester) => _open(tester, 'К сериям');

  /// Match the actual control around its text, rather than a text node which
  /// cannot own keyboard focus itself.
  static Finder action(String label) => find.ancestor(
    of: find.text(label),
    matching: find.byWidgetPredicate((widget) => widget is ButtonStyleButton || widget is TvFocusable),
  );

  static Future<void> expectFocused(WidgetTester tester, Finder target, String step) => E2eHarness.waitFor(
    tester,
    () => _ready(target) && _focused(target) && target.hitTestable().evaluate().length == 1,
    step,
  );

  /// Optional directional navigation is bounded and always checks the intended
  /// control before Select; it never changes FocusNodes or taps by coordinate.
  static Future<void> activate(
    WidgetTester tester,
    Finder target, {
    required String step,
    LogicalKeyboardKey? direction,
    int maxSteps = 8,
  }) async {
    await E2eHarness.waitFor(tester, () => _ready(target), '$step ready');
    if (direction != null) {
      for (var index = 0; index < maxSteps && !_focused(target); index++) {
        await tester.sendKeyEvent(direction);
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(_focused(target), isTrue, reason: '$step target not reached; focus=${FocusManager.instance.primaryFocus}');
    }
    await expectFocused(tester, target, '$step focused');
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pump();
  }

  static Future<void> holdSelect(WidgetTester tester) async {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.select);
    try {
      await tester.pump(const Duration(milliseconds: 700));
      await tester.sendKeyRepeatEvent(LogicalKeyboardKey.select);
      await tester.pump();
    } finally {
      await tester.sendKeyUpEvent(LogicalKeyboardKey.select);
    }
  }

  static Future<void> chooseEpisode(WidgetTester tester, int number) async {
    int? focusedNumber() => int.tryParse(
      RegExp(r'^Серия\s+(\d+)').firstMatch(FocusManager.instance.primaryFocus?.debugLabel ?? '')?.group(1) ?? '',
    );
    await E2eHarness.waitFor(tester, () => focusedNumber() != null, 'episode chooser focus');
    // The TV chooser is ordered newest-to-oldest. Focus revelation scrolls the
    // real list, including choices outside the initial viewport.
    for (var step = 0; step < 200 && focusedNumber() != number; step++) {
      final current = focusedNumber();
      if (current == null) {
        fail('episode chooser lost focus');
      }
      await tester.sendKeyEvent(current < number ? LogicalKeyboardKey.arrowUp : LogicalKeyboardKey.arrowDown);
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(focusedNumber(), number, reason: 'Requested episode was not reached by the TV remote');
    final label = FocusManager.instance.primaryFocus?.debugLabel;
    if (label == null) {
      fail('Requested episode lost focus before Select');
    }
    await activate(tester, action(label), step: 'episode $number');
  }

  static bool _focused(Finder target) {
    final focused = FocusManager.instance.primaryFocus?.context;
    if (focused == null) {
      return false;
    }
    final targets = target.evaluate().toSet();
    var matches = targets.contains(focused);
    focused.visitAncestorElements((element) {
      matches |= targets.contains(element);

      return !matches;
    });

    return matches;
  }

  static bool _ready(Finder target) {
    final elements = target.evaluate().toList();
    if (elements.length != 1) {
      return false;
    }
    final route = ModalRoute.of(elements.single);
    final widget = elements.single.widget;

    return route?.isCurrent == true &&
        (route?.animation == null || route?.animation?.status == AnimationStatus.completed) &&
        (widget is! ButtonStyleButton || widget.onPressed != null);
  }

  static Future<void> _open(WidgetTester tester, String target) async {
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump(const Duration(milliseconds: 200));
    await E2eHarness.waitFor(
      tester,
      () => FocusManager.instance.primaryFocus?.debugLabel == 'К сериям',
      'player menu focus',
      timeout: const Duration(seconds: 5),
    );
    if (target != 'К сериям') {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
    }
    for (var step = 0; step < 8 && FocusManager.instance.primaryFocus?.debugLabel != target; step++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
    }
    expect(
      FocusManager.instance.primaryFocus?.debugLabel,
      target,
      reason: 'Player menu target not reached; refusing to activate another control',
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pump();
  }
}
