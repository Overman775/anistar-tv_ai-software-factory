import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';

import '../../../support/test_app.dart';

void main() {
  testWidgets('places child content over the TV background', (tester) async {
    await pumpTvApp(tester, const TvBackdrop(child: Text('Каталог')));

    expect(find.text('Каталог'), findsOneWidget);
    expect(find.byType(Stack), findsAtLeastNWidgets(1));
  });
}
