import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';

import '../../../support/test_app.dart';

void main() {
  for (final (name, size) in [('compact', compactTvSize), ('wide', wideTvSize)]) {
    testWidgets('error/retry TV state at $name viewport', (tester) async {
      var actionCalls = 0;
      await pumpTvApp(
        tester,
        TvBackdrop(
          child: TvStateView(
            icon: Icons.cloud_off_rounded,
            title: 'Каталог недоступен',
            message: 'Проверьте подключение',
            actionLabel: 'Попробовать снова',
            onAction: () => actionCalls++,
          ),
        ),
        size: size,
      );
      await tester.pumpAndSettle();
      expect(actionCalls, 0);
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/tv_state_$name.png'));
    }, tags: ['golden']);
  }
}
