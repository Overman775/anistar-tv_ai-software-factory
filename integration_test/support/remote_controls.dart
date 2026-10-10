// Each pump commits a separate remote focus transition.
// ignore_for_file: prefer-moving-to-variable

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// Navigate the visible player menu, without activating controls by touch.
abstract final class RemoteControls {
  static Future<void> openQuality(WidgetTester tester) => _open(tester, 'Качество');

  static Future<void> openEpisodes(WidgetTester tester) => _open(tester, 'Серии');

  static Future<void> nextEpisode(WidgetTester tester) => _open(tester, 'Следующая серия');

  static Future<void> previousEpisode(WidgetTester tester) => _open(tester, 'Предыдущая серия');

  static Future<void> backToEpisodes(WidgetTester tester) => _open(tester, 'К сериям');

  static Future<void> _open(WidgetTester tester, String target) async {
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump(const Duration(milliseconds: 200));
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (FocusManager.instance.primaryFocus?.debugLabel != 'К сериям') {
      if (DateTime.now().isAfter(deadline)) {
        fail('Player menu did not receive focus.');
      }
      await tester.pump(const Duration(milliseconds: 100));
    }
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
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pump();
  }
}
