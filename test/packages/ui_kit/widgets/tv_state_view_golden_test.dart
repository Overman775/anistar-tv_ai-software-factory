import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';

import '../../../support/test_app.dart';

void main() {
  testWidgets('error/retry TV state at the common TV profile', (tester) async {
    var actionCalls = 0;
    await testScreenGolden(
      tester,
      'tv_state',
      screen: TvBackdrop(
        child: TvStateView(
          icon: Icons.cloud_off_rounded,
          title: 'Каталог недоступен',
          message: 'Проверьте подключение',
          actionLabel: 'Попробовать снова',
          onAction: () => actionCalls++,
        ),
      ),
    );
    expect(actionCalls, 0);
    expect(tester.takeException(), isNull);
  }, tags: ['golden']);
}
