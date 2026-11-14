// Pins the fullscreen golden profiles: window metrics, text scale and baseline names.
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';

import 'test_app.dart';

void main() {
  test('golden profiles keep the planned windows at DPR 1', () {
    for (final (name, size, platform) in [
      ('tv', const Size(960, 540), AppDeviceProfile.tv),
      ('phonePortrait', const Size(360, 800), AppDeviceProfile.mobile),
      ('phoneLandscape', const Size(800, 360), AppDeviceProfile.mobile),
    ]) {
      final profile = GoldenProfile.values.singleWhere((candidate) => candidate.name == name);
      expect(profile.logicalSize, size, reason: '$name keeps the planned logical window');
      expect(profile.devicePixelRatio, 1, reason: '$name captures 1:1');
      expect(profile.platform, platform, reason: '$name selects its pump harness');
    }
  });

  test('baseline names follow scenario, profile and large-text suffix', () {
    expect(screenGoldenFile('catalog_loading', GoldenProfile.tv), 'goldens/catalog_loading.tv.png');
    expect(
      screenGoldenFile('catalog_loading', GoldenProfile.phonePortrait),
      'goldens/catalog_loading.phonePortrait.png',
    );
    expect(
      screenGoldenFile('catalog_loading', GoldenProfile.phonePortrait, GoldenTextScale.large),
      'goldens/catalog_loading.phonePortrait.largeText.png',
    );
    expect(
      screenGoldenFile('catalog', GoldenProfile.phoneLandscape, GoldenTextScale.large),
      'goldens/catalog.phoneLandscape.largeText.png',
    );
  });

  for (final profile in GoldenProfile.values) {
    testWidgets('profile ${profile.name} drives the test window', (tester) async {
      late MediaQueryData media;
      await pumpScreenGolden(
        tester,
        Builder(
          builder: (context) {
            media = MediaQuery.of(context);
            return const SizedBox.shrink();
          },
        ),
        profile: profile,
      );
      expect(tester.view.physicalSize, profile.logicalSize * profile.devicePixelRatio);
      expect(tester.view.devicePixelRatio, profile.devicePixelRatio);
      expect(media.size, profile.logicalSize);
      expect(media.textScaler.scale(10), 10);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('large text scales text while the window keeps the profile', (tester) async {
    late MediaQueryData media;
    await pumpScreenGolden(
      tester,
      Builder(
        builder: (context) {
          media = MediaQuery.of(context);
          return const SizedBox.shrink();
        },
      ),
      profile: GoldenProfile.phonePortrait,
      textScale: GoldenTextScale.large,
    );
    expect(media.size, GoldenProfile.phonePortrait.logicalSize);
    expect(tester.view.devicePixelRatio, 1);
    expect(media.textScaler.scale(10), 20);
    expect(tester.takeException(), isNull);
  });
}
