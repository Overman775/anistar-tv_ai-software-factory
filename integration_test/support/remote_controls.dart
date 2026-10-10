import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// Navigate the visible player menu, without activating controls by touch.
abstract final class RemoteControls {
  static Future<void> openQuality(WidgetTester tester) => _open(tester, 1);

  static Future<void> openEpisodes(WidgetTester tester) => _open(tester, 2);

  static Future<void> backToEpisodes(WidgetTester tester) => _open(tester, 0);

  static Future<void> _open(WidgetTester tester, int steps) async {
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump(const Duration(milliseconds: 200));
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (FocusManager.instance.primaryFocus?.debugLabel != 'К сериям') {
      if (DateTime.now().isAfter(deadline)) {
        fail('Player menu did not receive focus.');
      }
      await tester.pump(const Duration(milliseconds: 100));
    }
    for (var step = 0; step < steps; step++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
    }
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pump();
  }
}
