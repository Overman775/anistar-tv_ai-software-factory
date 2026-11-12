import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';

import '../../../support/test_app.dart';

void main() {
  test('all public symbols map to distinct glyphs in the bundled Lucide font', () {
    final glyphs = AppIconType.values.map((symbol) => symbol.glyph).toSet();
    expect(glyphs, hasLength(AppIconType.values.length));
    expect(glyphs.map((glyph) => glyph.fontFamily).toSet(), {'Lucide'});
    expect(glyphs.map((glyph) => glyph.fontPackage).toSet(), {'lucide_icons_flutter'});
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
    expect(
      tester
          .widget<Icon>(find.byWidgetPredicate((widget) => widget is Icon && widget.semanticLabel == 'Воспроизвести'))
          .icon,
      AppIconType.play.glyph,
    );
    expect(find.bySemanticsLabel('Воспроизвести'), findsOneWidget);
    expect(find.bySemanticsLabel('check'), findsNothing);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });
}
