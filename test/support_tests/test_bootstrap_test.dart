import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_app.dart';

void main() {
  test('unit tests reject HTTP client creation before any socket opens', () {
    expect(HttpClient.new, throwsStateError);
  });

  testWidgets('widget tests keep HTTP isolated and restore their TV view', (tester) async {
    expect(HttpClient.new, throwsStateError);
    await pumpTvApp(tester, const SizedBox.shrink(), size: wideTvSize);
    expect(tester.view.physicalSize, wideTvSize);
    expect(tester.view.devicePixelRatio, 1);
  });

  testWidgets('shared viewport keeps logical size, DPR, text scale and motion deterministic', (tester) async {
    late MediaQueryData media;
    await pumpMobileApp(
      tester,
      Builder(
        builder: (context) {
          media = MediaQuery.of(context);

          return const SizedBox.shrink();
        },
      ),
      size: const Size(320, 640),
      devicePixelRatio: 2,
      textScale: 2,
      disableAnimations: true,
    );

    expect(tester.view.physicalSize, const Size(640, 1280));
    expect(tester.view.devicePixelRatio, 2);
    expect(media.size, const Size(320, 640));
    expect(media.textScaler.scale(10), 20);
    expect(media.disableAnimations, isTrue);
  });

  testWidgets('TV viewport inherits accessibility preferences until explicitly overridden', (tester) async {
    tester.platformDispatcher
      ..textScaleFactorTestValue = 2
      ..accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(() {
      tester.platformDispatcher
        ..clearTextScaleFactorTestValue()
        ..clearAccessibilityFeaturesTestValue();
    });
    late MediaQueryData inherited;
    await pumpTvApp(
      tester,
      Builder(
        builder: (context) {
          inherited = MediaQuery.of(context);

          return const SizedBox.shrink();
        },
      ),
    );
    expect(inherited.textScaler.scale(10), 20);
    expect(inherited.disableAnimations, isTrue);

    late MediaQueryData overridden;
    await pumpTvApp(
      tester,
      Builder(
        builder: (context) {
          overridden = MediaQuery.of(context);

          return const SizedBox.shrink();
        },
      ),
      textScale: 1,
      disableAnimations: false,
    );
    expect(overridden.textScaler.scale(10), 10);
    expect(overridden.disableAnimations, isFalse);
  });
}
