import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';

import '../../../support/test_app.dart';

void main() {
  testWidgets('renders a title, optional subtitle and trailing content', (tester) async {
    await pumpTvApp(
      tester,
      const TvSectionHeader(title: 'Серии', subtitle: 'Все доступные выпуски', trailing: Text('12')),
    );

    expect(find.text('Серии'), findsOneWidget);
    expect(find.text('Все доступные выпуски'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
  });
}
