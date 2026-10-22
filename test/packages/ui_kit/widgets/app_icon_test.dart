import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';

import '../../../support/test_app.dart';

void main() {
  test('all public Lucide symbols resolve to bundled SVG data', () async {
    for (final symbol in AppIconType.values) {
      final source = await rootBundle.loadString('packages/${Assets.package}/assets/icons/${symbol.assetName}.svg');
      expect(source, contains('<svg'), reason: symbol.name);
      expect(source, contains('viewBox="0 0 24 24"'), reason: symbol.name);
    }
  });

  testWidgets('informative icons expose a label and decorative icons stay silent', (tester) async {
    final semantics = tester.ensureSemantics();

    await pumpTvApp(
      tester,
      const Row(
        children: [
          AppIcon(AppIconType.play, semanticLabel: 'Воспроизвести'),
          AppIcon(AppIconType.check),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Воспроизвести'), findsOneWidget);
    expect(find.bySemanticsLabel('check'), findsNothing);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });
}
