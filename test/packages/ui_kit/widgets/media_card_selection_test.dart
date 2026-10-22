import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';

import '../../../support/test_app.dart';

void main() {
  for (final variant in [MediaCardVariant.poster, MediaCardVariant.landscape]) {
    testWidgets('$variant selection remains visibly distinct without focus', (tester) async {
      const capture = ValueKey('card-pixels');
      final pixels = <List<int>>[];
      for (final selected in [false, true]) {
        await pumpMobileApp(
          tester,
          Center(
            child: RepaintBoundary(
              key: capture,
              child: SizedBox(
                width: variant == MediaCardVariant.poster ? 240 : 219,
                child: MediaCard(
                  label: 'Название аниме',
                  variant: variant,
                  selected: selected,
                  onPressed: () => fail('Unexpected activation'),
                ),
              ),
            ),
          ),
          disableAnimations: true,
        );
        await tester.pumpAndSettle();
        pixels.add(await _capturePixels(tester, find.byKey(capture)));
      }
      expect(
        pixels.last,
        isNot(orderedEquals(pixels.first)),
        reason: 'Selected media must remain visible after focus leaves',
      );
    });

    testWidgets('$variant unfocused touch press is visible and cancellation clears it', (tester) async {
      const capture = ValueKey('press-pixels');
      final target = find.byKey(capture);
      final settle = tester.pumpAndSettle;
      final startGesture = tester.startGesture;
      final focus = FocusNode();
      addTearDown(focus.dispose);
      var calls = 0;
      await pumpMobileApp(
        tester,
        Center(
          child: RepaintBoundary(
            key: capture,
            child: SizedBox(
              width: variant == MediaCardVariant.poster ? 240 : 219,
              child: MediaCard(label: 'Нажать', variant: variant, focusNode: focus, onPressed: () => calls++),
            ),
          ),
        ),
        disableAnimations: true,
      );
      await settle();
      final resting = await _capturePixels(tester, target);
      final center = tester.getCenter(target);
      final cancelled = await startGesture(center);
      await settle();
      final pressed = await _capturePixels(tester, target);
      expect(focus.hasFocus, isFalse, reason: 'Pointer-down must be tested before tap requests focus');
      expect(pressed, isNot(orderedEquals(resting)), reason: 'Opaque media must not hide touch-down feedback');
      await cancelled.cancel();
      await settle();
      expect(await _capturePixels(tester, target), orderedEquals(resting));
      expect(calls, 0);
      final released = await startGesture(center);
      await tester.pump();
      await released.up();
      await settle();
      expect(calls, 1);
    });
  }
}

Future<List<int>> _capturePixels(WidgetTester tester, Finder target) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(target);
  final bytes = await tester.runAsync(() async {
    final image = await boundary.toImage();
    try {
      final data = await image.toByteData();
      if (data == null) {
        throw StateError('Card pixels could not be captured');
      }
      // Corner antialias alone cannot communicate state. Retain the image,
      // straight edges and any genuine selected/pressed indicator.

      return [
        for (var y = 0; y < image.height; y++)
          for (var x = 0; x < image.width; x++)
            if (!((x < 12 || x >= image.width - 12) && (y < 12 || y >= image.height - 12)))
              for (var channel = 0; channel < 4; channel++) data.getUint8((y * image.width + x) * 4 + channel),
      ];
    } finally {
      image.dispose();
    }
  });

  return bytes ?? (throw StateError('Card pixels could not be captured'));
}
