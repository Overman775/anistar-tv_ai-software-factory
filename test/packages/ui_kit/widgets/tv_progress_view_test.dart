import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';

import '../../../support/test_app.dart';

void main() {
  testWidgets('renders the TV progress state', (tester) async {
    await pumpTvApp(tester, const TvProgressView(label: 'Загружаем каталог…'));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Загружаем каталог…'), findsOneWidget);
  });
}
