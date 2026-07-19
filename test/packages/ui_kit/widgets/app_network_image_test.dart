import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ui_kit/ui_kit.dart';

void main() {
  testWidgets('uses the shared fallback for an invalid image URL', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: const Scaffold(
          body: AppNetworkImage(imageUrl: 'not-a-url', semanticLabel: 'Постер аниме'),
        ),
      ),
    );

    expect(find.byIcon(Icons.broken_image_outlined), findsOneWidget);
    expect(tester.getSemantics(find.byType(AppNetworkImage)).label, contains('Постер аниме'));
  });

  testWidgets('applies the shared Inter TV typography', (tester) async {
    late TextStyle? style;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Builder(
          builder: (context) {
            style = Theme.of(context).textTheme.titleLarge;

            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(style?.fontFamily, TvTypography.fontFamily);
  });
}
