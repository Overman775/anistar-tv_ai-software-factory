import 'package:anistar_tv/packages/features/catalog/presentation/widgets/catalog_tail.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../../support/test_app.dart';

void main() {
  for (final size in [const Size(200, 300), const Size(160, 240)]) {
    testWidgets('long pagination error at 200% fits its $size card and can retry', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      var calls = 0;
      final settle = tester.pumpAndSettle;
      await pumpTvApp(
        tester,
        Center(
          child: SizedBox(
            width: size.width,
            height: size.height,
            child: CatalogTail(
              error: List.filled(5, 'Не удалось загрузить следующую страницу.').join(' '),
              onRetry: () => calls++,
            ),
          ),
        ),
      );
      await settle();
      final tail = find.byType(CatalogTail);
      await tester.tap(tail);
      await settle();
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      expect(calls, 2);
      expect(tester.takeException(), isNull);
    });
  }
}
