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
  });
}
