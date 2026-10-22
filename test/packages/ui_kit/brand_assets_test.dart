import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';

import '../../support/test_app.dart';

void main() {
  test('iOS icon catalog contains opaque launcher artwork at every declared size', () async {
    const directory = 'ios/Runner/Assets.xcassets/AppIcon.appiconset';
    final catalog = jsonDecode(await File('$directory/Contents.json').readAsString());
    if (catalog case {'images': final List<Object?> entries}) {
      expect(entries, isNotEmpty);
      for (final entry in entries) {
        if (entry case {'filename': final String name, 'size': final String size, 'scale': final String scale}) {
          final image = await _decodeFile('$directory/$name');
          try {
            final expectedSize = (double.parse(size.split('x').first) * double.parse(scale.split('x').first)).round();
            expect(image.width, expectedSize, reason: name);
            expect(image.height, expectedSize, reason: name);
            final pixels = await image.toByteData(format: ui.ImageByteFormat.rawStraightRgba);
            if (pixels == null) {
              fail('Could not decode $name');
            }
            for (var offset = 3; offset < pixels.lengthInBytes; offset += 4) {
              if (pixels.getUint8(offset) != 255) {
                fail('$name contains transparent pixels');
              }
            }
          } finally {
            image.dispose();
          }
        } else {
          fail('Every AppIcon slot must declare its image, size and scale');
        }
      }
    } else {
      fail('AppIcon catalog must declare its images');
    }
    final source = await _decodeFile('lib/packages/ui_kit/assets/images/anistar_launcher.png');
    final marketing = await _decodeFile('$directory/Icon-App-1024x1024@1x.png');
    try {
      final original = await source.toByteData(format: ui.ImageByteFormat.rawStraightRgba);
      final generated = await marketing.toByteData(format: ui.ImageByteFormat.rawStraightRgba);
      expect(original, isNotNull);
      expect(
        generated?.buffer.asUint8List(),
        original?.buffer.asUint8List(),
        reason: 'iOS must use existing launcher artwork',
      );
    } finally {
      source.dispose();
      marketing.dispose();
    }
  });

  test('iOS LaunchScreen preserves the banner aspect and dark background', () async {
    const directory = 'ios/Runner/Assets.xcassets';
    final storyboard = await File('ios/Runner/Base.lproj/LaunchScreen.storyboard').readAsString();
    expect(storyboard, contains('contentMode="scaleAspectFit" image="LaunchImage"'));
    expect(storyboard, contains('image="LaunchBackground"'));
    final catalog = jsonDecode(await File('$directory/LaunchImage.imageset/Contents.json').readAsString());
    if (catalog case {'images': final List<Object?> entries}) {
      expect(entries, hasLength(3));
      for (final entry in entries) {
        if (entry case {'filename': final String name, 'scale': final String scale}) {
          final image = await _decodeFile('$directory/LaunchImage.imageset/$name');
          try {
            final multiplier = int.parse(scale.split('x').first);
            expect(image.width, multiplier * 320, reason: name);
            expect(image.height, multiplier * 180, reason: name);
            expect(image.width / image.height, 1280 / 720, reason: 'Banner must retain its aspect ratio');
          } finally {
            image.dispose();
          }
        } else {
          fail('Every LaunchImage scale must have artwork');
        }
      }
    } else {
      fail('LaunchImage catalog must declare its images');
    }
    final background = await _decodeFile('$directory/LaunchBackground.imageset/background.png');
    try {
      final pixels = await background.toByteData(format: ui.ImageByteFormat.rawStraightRgba);
      expect(pixels?.buffer.asUint8List(), [16, 18, 20, 255]);
    } finally {
      background.dispose();
    }
  });

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
    expect(TvTypography.fontFamily, 'packages/ui_kit/Manrope');
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

Future<ui.Image> _decodeFile(String path) async {
  final codec = await ui.instantiateImageCodec(await File(path).readAsBytes());
  try {
    return (await codec.getNextFrame()).image;
  } finally {
    codec.dispose();
  }
}
