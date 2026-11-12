import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';

import '../../../support/test_app.dart';

void main() {
  for (final reduced in [false, true]) {
    testWidgets('focus frame preserves geometry and uses enter280 exit180 reduced=$reduced', (tester) async {
      final pump = tester.pump;
      final settle = tester.pumpAndSettle;
      final tween = find.byType(TweenAnimationBuilder<double>);
      Border painted() => _border(tester);
      final active = ValueNotifier(false);
      addTearDown(active.dispose);
      await pumpTvApp(
        tester,
        MediaQuery(
          data: MediaQueryData(disableAnimations: reduced),
          child: Center(
            child: ValueListenableBuilder<bool>(
              valueListenable: active,
              builder: (_, focused, _) => AppFocusBorder(
                focused: focused,
                child: const SizedBox(key: ValueKey('bounds'), width: 160, height: 60),
              ),
            ),
          ),
        ),
      );
      await settle();
      final bounds = find.byKey(const ValueKey('bounds'));
      final size = tester.getSize(bounds);
      active.value = true;
      await pump();
      if (reduced) {
        expect(tween, findsNothing);
        expect(painted().top.color, AppPalette.focusOutline);
      } else {
        final frame = tester.widget<TweenAnimationBuilder<double>>(tween);
        expect(frame.duration, const Duration(milliseconds: 280));
        expect(frame.curve, const Cubic(0.215, 0.61, 0.355, 1));
        await pump(const Duration(milliseconds: 140));
        expect(painted().top.color.a, closeTo(const Cubic(0.215, 0.61, 0.355, 1).transform(0.5), 0.01));
      }
      await settle();
      // The completed entry must repaint beyond its earlier midpoint sample.
      final entered = painted().top;
      expect(entered.color, AppPalette.focusOutline);
      expect(entered.width, 2);
      // Entry and exit require distinct geometry samples after the animation.
      expect(tester.getSize(bounds), size);
      active.value = false;
      await pump();
      if (reduced) {
        expect(painted().top.color, Colors.transparent);
      } else {
        final exit = tester.widget<TweenAnimationBuilder<double>>(tween);
        expect(exit.duration, const Duration(milliseconds: 180));
        expect(exit.curve, const Cubic(0.55, 0.055, 0.675, 0.19));
        await pump(const Duration(milliseconds: 90));
        // Sample the independent exit midpoint after advancing its own clock.
        expect(painted().top.color.a, closeTo(1 - const Cubic(0.55, 0.055, 0.675, 0.19).transform(0.5), 0.01));
      }
      await settle();
      // Sample completion after the exit clock has fully advanced.
      expect(painted().top.color, Colors.transparent);
      // Exit must retain the same geometry already checked after entry.
      expect(tester.getSize(bounds), size);
    });
  }
}

Border _border(WidgetTester tester) {
  final decoration = tester
      .widgetList<DecoratedBox>(find.descendant(of: find.byType(AppFocusBorder), matching: find.byType(DecoratedBox)))
      .singleWhere((box) => box.position == DecorationPosition.foreground)
      .decoration;
  if (decoration case BoxDecoration(:final Border border)) {
    return border;
  }
  throw TestFailure('Expected a painted focus border');
}
