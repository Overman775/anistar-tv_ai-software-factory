import 'dart:ui' as ui;

// Seed the production UI kit's public image provider with bundled fixture bytes.
// ignore: depend_on_referenced_packages
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';

const decodedFixtureUrl = 'https://fixture.test/decoded-local-poster.png';

Future<ui.Image> cacheDecodedFixtureImage(WidgetTester tester) async {
  final image = await tester.runAsync(() async {
    final bytes = await rootBundle.load(Assets.images.anistarLauncher.keyName);
    final codec = await ui.instantiateImageCodec(bytes.buffer.asUint8List());
    final frame = await codec.getNextFrame();
    codec.dispose();

    return frame.image;
  });
  if (image == null) {
    throw StateError('Bundled fixture image did not decode');
  }
  final cache = PaintingBinding.instance.imageCache
    ..putIfAbsent(
      const CachedNetworkImageProvider(decodedFixtureUrl),
      () => OneFrameImageStreamCompleter(Future.value(ImageInfo(image: image))),
    );
  addTearDown(() {
    cache
      ..clear()
      ..clearLiveImages();
  });

  return image;
}
