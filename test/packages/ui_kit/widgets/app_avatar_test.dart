import 'dart:async';

// This regression seeds the cached image provider with a pending frame.
// ignore: depend_on_referenced_packages
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';

import '../../../support/test_app.dart';

void main() {
  test('initials retain the first two non-empty name parts', () {
    expect(AppAvatar.initialsOf('  Анна   Каренина  '), 'АК');
    expect(AppAvatar.initialsOf('  Аня '), 'А');
  });

  for (final imageUrl in [null, 'not-a-url']) {
    testWidgets('avatar keeps initials available without a usable image URL: $imageUrl', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpMobileApp(
        tester,
        Center(
          child: AppAvatar(name: 'Анна Каренина', imageUrl: imageUrl),
        ),
        disableAnimations: true,
      );

      expect(find.text('АК'), findsOneWidget);
      expect(find.bySemanticsLabel('Анна Каренина'), findsOneWidget);
      expect(tester.widget<AppNetworkImage>(find.byType(AppNetworkImage)).imageUrl, imageUrl);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    });
  }

  testWidgets('avatar retains initials while a valid image is unresolved', (tester) async {
    const imageUrl = 'https://fixture.test/avatar.png';
    final pendingImage = Completer<ImageInfo>();
    final provider = ResizeImage(const CachedNetworkImageProvider(imageUrl), width: AppSizes.touchControl.round());
    final imageKey = await provider.obtainKey(ImageConfiguration.empty);
    final cache = PaintingBinding.instance.imageCache
      ..clear()
      ..clearLiveImages()
      ..putIfAbsent(imageKey, () => OneFrameImageStreamCompleter(pendingImage.future));
    addTearDown(() {
      cache
        ..clear()
        ..clearLiveImages();
    });
    final semantics = tester.ensureSemantics();
    await pumpMobileApp(
      tester,
      const Center(
        child: AppAvatar(name: 'Анна Каренина', imageUrl: imageUrl),
      ),
      disableAnimations: true,
    );
    await tester.pump();

    expect(find.text('АК'), findsOneWidget);
    expect(find.bySemanticsLabel('Анна Каренина'), findsOneWidget);
    expect(tester.widget<AppNetworkImage>(find.byType(AppNetworkImage)).imageUrl, imageUrl);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });
}
