import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

// This regression inspects the UI kit's cached image implementation.
// ignore: depend_on_referenced_packages
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';

import '../../../support/test_app.dart';

void main() {
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
    Future<void> mount(double width) => pumpTvApp(
      tester,
      MediaQuery(
        data: const MediaQueryData(devicePixelRatio: 2),
        child: Center(
          child: SizedBox(
            width: width,
            height: 300,
            child: const AppNetworkImage(imageUrl: 'https://fixture.test/poster.jpg'),
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
