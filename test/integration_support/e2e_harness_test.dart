import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../integration_test/support/e2e_harness.dart';

void main() {
  testWidgets('state wait rejects paused lifecycle before scheduling an unavailable frame', (tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    try {
      await expectLater(
        () => E2eHarness.waitFor(tester, () => false, 'background video'),
        throwsA(isA<TestFailure>().having((failure) => failure.message, 'reason', contains('frames are disabled'))),
      );
    } finally {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    }
  });

  testWidgets('state wait reports framework failure before evaluating readiness', (tester) async {
    await tester.pumpWidget(Builder(builder: (_) => throw FlutterError('broken E2E layout')));
    var checks = 0;
    await expectLater(
      () => E2eHarness.waitFor(tester, () {
        checks++;

        return false;
      }, 'catalog ready'),
      throwsA(isA<TestFailure>()),
    );
    expect(checks, 0, reason: 'A broken layout must fail immediately instead of waiting 45 seconds');
  });

  testWidgets('state wait timeout includes the step and supplied diagnostics', (tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await expectLater(
      () => E2eHarness.waitFor(
        tester,
        () => false,
        'episode ready',
        diagnostics: () => 'sheet still open',
        timeout: Duration.zero,
      ),
      throwsA(
        isA<TestFailure>().having(
          (failure) => failure.message,
          'diagnostic',
          allOf(contains('episode ready'), contains('sheet still open'), contains('focus:'), contains('native error:')),
        ),
      ),
    );
  });
}
