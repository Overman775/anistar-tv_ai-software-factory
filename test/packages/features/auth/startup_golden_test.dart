import 'dart:async';

import 'package:anistar_tv/app/app.dart';
import 'package:anistar_tv/packages/features/auth/auth_providers.dart';
import 'package:core/data.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:networking/networking.dart';

import '../../../mocks/features/auth/fake_auth_repository.dart';
import '../../../support/test_app.dart';

void main() {
  const unavailable = RequestFailure(
    message:
        'AniStar недоступен: текущее и следующие зеркала не отвечают. Проверьте интернет и повторите через минуту.',
  );
  for (final (profile, textScale) in [
    (GoldenProfile.tv, GoldenTextScale.normal),
    (GoldenProfile.phonePortrait, GoldenTextScale.large),
  ]) {
    for (final stage in ['site', 'session', 'error']) {
      testWidgets('startup $stage at ${profile.name}${textScale == GoldenTextScale.large ? ' 200% text' : ''}', (
        tester,
      ) async {
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
        await testScreenGolden(
          tester,
          'startup_$stage',
          profile: profile,
          textScale: textScale,
          screen: const App(),
          wrapInScaffold: false,
          overrides: [authRepositoryProvider.overrideWithValue(repository)],
          target: find.byType(MaterialApp).last,
          prepare: (tester) async {
            // Indeterminate progress stays animated; snapshot one deterministic frame.
            await tester.pump(const Duration(milliseconds: 100));
            expect(tester.takeException(), isNull);
            if (stage == 'error') {
              await tester.pumpAndSettle();
              expect(find.byKey(const ValueKey('startup_retry')).hitTestable(), findsOneWidget);
              if (textScale == GoldenTextScale.large) {
                const label = 'Не удалось подключиться к AniStar';
                const word = 'подключиться';
                final paragraph = tester.renderObject<RenderParagraph>(find.text(label));
                final start = label.indexOf(word);
                expect(
                  paragraph
                      .getBoxesForSelection(TextSelection(baseOffset: start, extentOffset: start + word.length))
                      .length,
                  1,
                  reason: 'The startup error heading must keep each word whole',
                );
              }
            }
          },
        );
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
