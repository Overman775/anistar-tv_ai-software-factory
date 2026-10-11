import 'dart:convert';

// This regression inspects the UI kit's cached image implementation.
// ignore: depend_on_referenced_packages
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';

import '../../../support/test_app.dart';

void main() {
  testWidgets('non-HTTP schemes render fallback without creating a network image', (tester) async {
    for (final url in ['file://localhost/p.jpg', 'ftp://cdn.test/p.jpg', 'https:///p.jpg']) {
      await pumpTvApp(tester, AppNetworkImage(imageUrl: url));
      expect(find.byIcon(Icons.broken_image_outlined), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('uses the shared fallback for an invalid image URL', (tester) async {
    await pumpTvApp(tester, const AppNetworkImage(imageUrl: 'not-a-url', semanticLabel: 'Постер аниме'));

    expect(find.byIcon(Icons.broken_image_outlined), findsOneWidget);
    expect(tester.getSemantics(find.byType(AppNetworkImage)).label, contains('Постер аниме'));
  });

  testWidgets('applies the shared Inter TV typography', (tester) async {
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
    final inter = families.singleWhere((entry) => entry['family'] == style?.fontFamily);
    final faces = inter['fonts']! as List<Object?>;
    expect(faces.whereType<Map<String, Object?>>().map((face) => face['weight']), containsAll([400, 500, 700]));
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
