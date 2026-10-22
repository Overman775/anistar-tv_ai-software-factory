import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';

import '../../../support/test_app.dart';

void main() {
  testWidgets('loading skeleton excludes interaction and announcements without shimmer in reduced motion', (
    tester,
  ) async {
    final focus = FocusNode();
    addTearDown(focus.dispose);
    final semantics = tester.ensureSemantics();
    var calls = 0;
    await pumpMobileApp(
      tester,
      TvSkeleton(
        isLoading: true,
        child: AppButton(label: 'Скрытое действие', focusNode: focus, onPressed: () => calls++),
      ),
      disableAnimations: true,
    );
    await tester.pumpAndSettle();
    focus.requestFocus();
    await tester.pump();
    expect(focus.hasFocus, isFalse);
    expect(find.bySemanticsLabel('Скрытое действие'), findsNothing);
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(calls, 0);
    semantics.dispose();
  });
}
