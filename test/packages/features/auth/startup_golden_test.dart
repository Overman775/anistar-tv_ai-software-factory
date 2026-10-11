import 'dart:async';

import 'package:anistar/anistar.dart';
import 'package:anistar_tv/app/app.dart';
import 'package:anistar_tv/packages/features/auth/auth_providers.dart';
import 'package:core/data.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../../mocks/features/auth/fake_auth_repository.dart';
import '../../../support/test_app.dart';

void main() {
  const unavailable = AnistarFailure(
    message:
        'AniStar недоступен: текущее и следующие зеркала не отвечают. Проверьте интернет и повторите через минуту.',
  );
  for (final (viewport, size, scale) in [
    ('compact', compactTvSize, 1.0),
    ('wide', wideTvSize, 1.0),
    ('portrait_scaled', const Size(390, 844), 2.0),
  ]) {
    for (final stage in ['site', 'session', 'error']) {
      testWidgets('startup $stage at $viewport', (tester) async {
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final repository = FakeAuthRepository();
        final site = Completer<void>();
        final session = Completer<Result<String?, Failure>>();
        if (stage == 'site') {
          repository.pendingSiteCheck = site;
        } else if (stage == 'session') {
          repository.pendingRestore = session;
        } else {
          repository.siteFailure = unavailable;
        }
        addTearDown(repository.close);
        await pumpTvApp(
          tester,
          const App(),
          size: size,
          wrapInScaffold: false,
          overrides: [authRepositoryProvider.overrideWithValue(repository)],
        );
        // Indeterminate progress stays animated; snapshot one deterministic frame.
        await tester.pump(const Duration(milliseconds: 100));
        expect(tester.takeException(), isNull);
        if (stage == 'error') {
          await tester.pumpAndSettle();
          expect(find.byKey(const ValueKey('startup_retry')).hitTestable(), findsOneWidget);
        }
        await expectLater(find.byType(MaterialApp).last, matchesGoldenFile('goldens/startup_${stage}_$viewport.png'));
        await tester.pumpWidget(const SizedBox.shrink());
        if (!site.isCompleted) {
          site.complete();
        }
        if (!session.isCompleted) {
          session.complete(const Result.success(null));
        }
        await tester.pump();
      }, tags: ['golden']);
    }
  }
}
