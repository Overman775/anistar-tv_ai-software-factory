import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';

import '../../../support/test_app.dart';

void main() {
  for (final reduced in [false, true]) {
    testWidgets('focus frame preserves geometry and uses enter280 exit200 reduced=$reduced', (tester) async {
      final pump = tester.pump;
      final settle = tester.pumpAndSettle;
      final tween = find.byType(TweenAnimationBuilder<Color?>);
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
      final frame = tester.widget<TweenAnimationBuilder<Color?>>(tween);
      expect(frame.duration, reduced ? Duration.zero : const Duration(milliseconds: 280));
      expect(frame.curve, Curves.easeOutCubic);
      if (!reduced) {
        await pump(const Duration(milliseconds: 140));
        expect(painted().top.color.a, closeTo(Curves.easeOutCubic.transform(0.5), 0.01));
      }
      await settle();
      // The completed entry must repaint beyond its earlier midpoint sample.
      // ignore: prefer-moving-to-variable
      final entered = painted().top;
      expect(entered.color, AppPalette.focusOutline);
      expect(entered.width, 2);
      // Entry and exit require distinct geometry samples after the animation.
      // ignore: prefer-moving-to-variable
      expect(tester.getSize(bounds), size);
      active.value = false;
      await pump();
      final exit = tester.widget<TweenAnimationBuilder<Color?>>(tween);
      expect(exit.duration, reduced ? Duration.zero : const Duration(milliseconds: 200));
      expect(exit.curve, Curves.easeInCubic);
      if (!reduced) {
        await pump(const Duration(milliseconds: 100));
        // Sample the independent exit midpoint after advancing its own clock.
        // ignore: prefer-moving-to-variable
        expect(painted().top.color.a, closeTo(1 - Curves.easeInCubic.transform(0.5), 0.01));
      }
      await settle();
      // Sample completion after the exit clock has fully advanced.
      // ignore: prefer-moving-to-variable
      expect(painted().top.color, Colors.transparent);
      // Exit must retain the same geometry already checked after entry.
      // ignore: avoid-duplicate-test-assertions, prefer-moving-to-variable
      expect(tester.getSize(bounds), size);
    });
  }
}

Border _border(WidgetTester tester) {
  final decoration = tester
      .widget<DecoratedBox>(find.descendant(of: find.byType(AppFocusBorder), matching: find.byType(DecoratedBox)))
      .decoration;
  if (decoration case BoxDecoration(:final Border border)) {
    return border;
  }
  throw TestFailure('Expected a painted focus border');
}
