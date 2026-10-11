import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';

import '../../support/test_app.dart';

void main() {
  test('generated package asset keys resolve from the app bundle', () async {
    for (final asset in Assets.images.values) {
      expect((await rootBundle.load(asset.keyName)).lengthInBytes, greaterThan(0));
    }
    for (final path in Assets.fonts.values) {
      expect((await rootBundle.load(path)).lengthInBytes, greaterThan(0));
    }
    expect(TvTypography.fontFamily, 'packages/ui_kit/Inter');
  });

  testWidgets('shared logo decodes the package image without an extra semantic label', (tester) async {
    await pumpTvApp(tester, const AnistarLogo(size: 32));
    await tester.runAsync(
      () => precacheImage(Assets.images.anistarLogo.provider(), tester.element(find.byType(AnistarLogo))),
    );
    await tester.pumpAndSettle();
    final image = tester.widget<Image>(find.descendant(of: find.byType(AnistarLogo), matching: find.byType(Image)));
    expect(image.excludeFromSemantics, isTrue);
    expect(tester.takeException(), isNull);
    expect(find.byType(RawImage), findsOneWidget);
    final decoded =
        tester.widget<RawImage>(find.byType(RawImage)).image ?? (throw StateError('Brand logo did not decode'));
    final pixels = await tester.runAsync(decoded.toByteData);
    expect(pixels?.getUint8(3), 0, reason: 'UI logo must have a transparent background');
  });
}
