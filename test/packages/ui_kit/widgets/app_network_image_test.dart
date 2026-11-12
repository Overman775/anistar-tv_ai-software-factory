import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

// This regression inspects the UI kit's cached image implementation.
// ignore: depend_on_referenced_packages
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';

import '../../../support/test_app.dart';

void main() {
  for (final profile in AppDeviceProfile.values) {
    testWidgets('$profile poster texture remains visible through both card badges', (tester) async {
      const url = 'https://fixture.test/texture.png';
      const width = 180;
      const height = 270;
      const light = Color(0xFFECBA80);
      const dark = Color(0xFF608CC8);
      const frame = ValueKey('textured-card');
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      for (var x = 0; x < width; x += 5) {
        canvas.drawRect(
          Rect.fromLTWH(x.toDouble(), 0, 5, height.toDouble()),
          Paint()..color = x % 10 == 0 ? light : dark,
        );
      }
      final picture = recorder.endRecording();
      final texture = picture.toImageSync(width, height);
      picture.dispose();
      final cache = PaintingBinding.instance.imageCache;
      const provider = CachedNetworkImageProvider(url);
      cache.putIfAbsent(provider, () => OneFrameImageStreamCompleter(Future.value(ImageInfo(image: texture))));
      addTearDown(() => cache.evict(provider));

      final content = Center(
        child: RepaintBoundary(
          key: frame,
          child: SizedBox(
            width: width.toDouble(),
            child: MediaCard(
              label: 'Аниме',
              imageUrl: url,
              heroTag: frame,
              ratingLabel: '9,2',
              showBookmark: true,
              onPressed: () => fail('Unexpected activation'),
            ),
          ),
        ),
      );
      if (profile == AppDeviceProfile.tv) {
        await pumpTvApp(tester, content, disableAnimations: true);
      } else {
        await pumpMobileApp(tester, content, disableAnimations: true);
      }
      await tester.pumpAndSettle();

      final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(frame));
      final snapshot = boundary.toImageSync();
      final data = await tester.runAsync(() => snapshot.toByteData(format: ui.ImageByteFormat.rawStraightRgba));
      snapshot.dispose();
      final pixels = data ?? (throw StateError('No captured card pixels'));
      const overlay = Color(0xA3101214);
      for (final (x, y, source) in [(12, 13, light), (17, 13, dark), (132, 5, light), (137, 5, dark)]) {
        final index = (y * width + x) * 4;
        final expected = Color.alphaBlend(overlay, source);
        final expectedRgb = expected.toARGB32();
        expect(pixels.getUint8(index), closeTo((expectedRgb >> 16) & 0xFF, 2));
        expect(pixels.getUint8(index + 1), closeTo((expectedRgb >> 8) & 0xFF, 2));
        expect(pixels.getUint8(index + 2), closeTo(expectedRgb & 0xFF, 2));
        expect(pixels.getUint8(index + 3), 255);
      }
    });
  }

  for (final mode in ['success', 'error', 'reduced']) {
    testWidgets('retains decoded Hero poster while replacement loads: $mode', (tester) async {
      const sourceUrl = 'https://fixture.test/source.png';
      const targetUrl = 'https://fixture.test/detail.png';
      final source =
          await tester.runAsync(() async {
            final bytes = await rootBundle.load(Assets.images.anistarLauncher.keyName);
            final codec = await ui.instantiateImageCodec(bytes.buffer.asUint8List());
            final frame = await codec.getNextFrame();
            codec.dispose();

            return frame.image;
          }) ??
          (throw StateError('Source image did not decode'));
      final target =
          await tester.runAsync(() async {
            final bytes = await rootBundle.load(Assets.images.anistarLogo.keyName);
            final codec = await ui.instantiateImageCodec(bytes.buffer.asUint8List());
            final frame = await codec.getNextFrame();
            codec.dispose();

            return frame.image;
          }) ??
          (throw StateError('Target image did not decode'));
      final pending = Completer<ImageInfo>();
      final cache = PaintingBinding.instance.imageCache
        ..putIfAbsent(
          const CachedNetworkImageProvider(sourceUrl),
          () => OneFrameImageStreamCompleter(Future.value(ImageInfo(image: source))),
        )
        ..putIfAbsent(const CachedNetworkImageProvider(targetUrl), () => OneFrameImageStreamCompleter(pending.future));
      addTearDown(() {
        cache
          ..clear()
          ..clearLiveImages();
      });
      await pumpTvApp(
        tester,
        MediaQuery(
          data: MediaQueryData(disableAnimations: mode == 'reduced'),
          child: const SizedBox(
            width: 200,
            height: 300,
            child: TvPosterHero(
              tag: 'test-poster',
              imageUrl: targetUrl,
              fallbackImageUrl: sourceUrl,
              semanticLabel: 'Аниме',
            ),
          ),
        ),
      );
      bool visible(ui.Image image) =>
          tester.widgetList<RawImage>(find.byType(RawImage)).any((raw) => raw.image?.isCloneOf(image) ?? false);
      for (var frame = 0; frame < 12; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
        expect(visible(source), isTrue);
        expect(visible(target), isFalse);
        expect(find.byType(TvSkeletonBox), findsNothing);
      }
      if (mode == 'error') {
        pending.completeError(StateError('Image unavailable'));
      } else {
        pending.complete(ImageInfo(image: target));
      }
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      await tester.pump(const Duration(milliseconds: 40));
      if (mode != 'error') {
        final targetImage = find.byWidgetPredicate(
          (widget) => widget is RawImage && (widget.image?.isCloneOf(target) ?? false),
        );
        expect(targetImage, findsOneWidget);
        final fades = tester.widgetList<FadeTransition>(
          find.ancestor(of: targetImage, matching: find.byType(FadeTransition)),
        );
        expect(
          fades.any((fade) {
            final opacity = fade.opacity.value;

            return opacity > 0 && opacity < 1;
          }),
          mode == 'success',
        );
      }
      for (var frame = 0; frame < 12; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
        expect(visible(source), isTrue);
      }
      await tester.pumpAndSettle();
      expect(visible(target), mode != 'error');
      expect(find.byType(AppIcon), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('non-HTTP schemes render fallback without creating a network image', (tester) async {
    for (final url in ['file://localhost/p.jpg', 'ftp://cdn.test/p.jpg', 'https:///p.jpg']) {
      await pumpTvApp(tester, AppNetworkImage(imageUrl: url));
      expect(find.byType(AppIcon), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('uses the shared fallback for an invalid image URL', (tester) async {
    await pumpTvApp(tester, const AppNetworkImage(imageUrl: 'not-a-url', semanticLabel: 'Постер аниме'));

    expect(find.byType(AppIcon), findsOneWidget);
    expect(tester.getSemantics(find.byType(AppNetworkImage)).label, contains('Постер аниме'));
  });

  testWidgets('applies the shared Manrope TV typography', (tester) async {
    late TextStyle? style;

    await pumpTvApp(
      tester,
      Builder(
        builder: (context) {
          style = Theme.of(context).textTheme.titleLarge;

          return const SizedBox.shrink();
        },
      ),
    );

    expect(style?.fontFamily, TvTypography.fontFamily);
    final manifest = jsonDecode(await rootBundle.loadString('FontManifest.json')) as List<Object?>;
    final families = manifest.whereType<Map<String, Object?>>();
    expect(families.map((entry) => entry['family']), contains(style?.fontFamily));
    final manrope = families.singleWhere((entry) => entry['family'] == style?.fontFamily);
    final fonts = manrope['fonts'] ?? (throw StateError('Font manifest entry has no faces'));
    final faces = fonts as List<Object?>;
    expect(
      faces.whereType<Map<String, Object?>>().map((face) => face['weight']),
      containsAll([400, 500, 600, 700, 800]),
    );
  });

  testWidgets('decode follows layout and DPR while retaining original disk cache for Hero', (tester) async {
    const url = 'https://fixture.test/poster.jpg';
    final cache = PaintingBinding.instance.imageCache;
    for (final width in [400, 800]) {
      final provider = ResizeImage(const CachedNetworkImageProvider(url), width: width);
      final key = await provider.obtainKey(ImageConfiguration.empty);
      final pending = Completer<ImageInfo>();
      cache.putIfAbsent(key, () => OneFrameImageStreamCompleter(pending.future));
      addTearDown(() => cache.evict(key));
    }
    Future<void> mount(double width) => pumpTvApp(
      tester,
      MediaQuery(
        data: const MediaQueryData(devicePixelRatio: 2),
        child: Center(
          child: SizedBox(
            width: width,
            height: 300,
            child: const AppNetworkImage(imageUrl: url),
          ),
        ),
      ),
    );
    final cachedImage = find.byType(CachedNetworkImage);
    await mount(200);
    final thumbnail = tester.widget<CachedNetworkImage>(cachedImage);
    expect(thumbnail.memCacheWidth, 400);
    expect(thumbnail.memCacheHeight, isNull);
    expect(thumbnail.maxWidthDiskCache, isNull);
    expect(thumbnail.maxHeightDiskCache, isNull);
    await mount(400);
    final detail = tester.widget<CachedNetworkImage>(cachedImage);
    expect(detail.memCacheWidth, 800);
    expect(detail.imageUrl, thumbnail.imageUrl);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
