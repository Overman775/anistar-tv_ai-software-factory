import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';

import '../../support/test_app.dart';

void main() {
  test('Android splash artwork fits the circular mask in every generated density and theme', () async {
    const resources = 'android/app/src/main/res';
    final wrapper = await File('$resources/drawable/android12splash_safe.xml').readAsString();
    final insetMatch = RegExp('android:inset="([0-9.]+)%"').firstMatch(wrapper);
    expect(insetMatch, isNotNull);
    final inset = double.parse(insetMatch?.group(1) ?? (throw StateError('Missing native splash inset'))) / 100;
    final artworkScale = 1 - inset * 2;
    final positive = greaterThan(0);
    expect(artworkScale, positive);
    expect(wrapper, contains('android:drawable="@drawable/android12splash"'));

    for (final theme in ['', 'night-']) {
      final styles = await File('$resources/values-${theme}v31/styles.xml').readAsString();
      expect(styles, contains('@drawable/android12splash_safe'), reason: 'Both launch themes need the safe area');
      for (final density in ['mdpi', 'hdpi', 'xhdpi', 'xxhdpi', 'xxxhdpi']) {
        final path = '$resources/drawable-$theme$density/android12splash.png';
        final codec = await ui.instantiateImageCodec(await File(path).readAsBytes());
        final frame = await codec.getNextFrame();
        codec.dispose();
        final image = frame.image;
        try {
          final pixels = await image.toByteData(format: ui.ImageByteFormat.rawStraightRgba);
          if (pixels == null) {
            throw StateError('Could not decode $path');
          }
          expect(image.width, image.height, reason: path);
          expect(pixels.getUint8(3), 0, reason: '$path must have a transparent background');
          final center = (image.width - 1) / 2;
          var maxRadiusSquared = 0.0;
          for (var y = 0; y < image.height; y++) {
            for (var x = 0; x < image.width; x++) {
              if (pixels.getUint8((y * image.width + x) * 4 + 3) == 0) {
                continue;
              }
              final dx = x - center;
              final dy = y - center;
              maxRadiusSquared = math.max(maxRadiusSquared, dx * dx + dy * dy);
            }
          }
          expect(maxRadiusSquared, positive, reason: '$path must contain the logo');
          // Android reserves a circle with diameter two thirds of the source canvas.
          // Foreground expansion and circular clipping preserve this safe area.
          final safeRadius = image.width / 3;
          expect(
            maxRadiusSquared * artworkScale * artworkScale,
            lessThanOrEqualTo(safeRadius * safeRadius),
            reason: '$path would clip the logo at the system splash mask',
          );
        } finally {
          image.dispose();
        }
      }
    }
  });

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
