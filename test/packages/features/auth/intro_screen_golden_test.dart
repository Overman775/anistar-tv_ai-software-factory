import 'package:anistar_tv/packages/features/auth/auth_providers.dart';
import 'package:anistar_tv/packages/features/auth/presentation/intro_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../../mocks/features/auth/fake_auth_repository.dart';
import '../../../support/test_app.dart';

void main() {
  for (final (name, size) in [('compact', compactTvSize), ('wide', wideTvSize)]) {
    testWidgets('intro panel at $name viewport', (tester) async {
      final repository = FakeAuthRepository();
      addTearDown(repository.close);
      await pumpTvApp(
        tester,
        const IntroScreen(),
        size: size,
        wrapInScaffold: false,
        overrides: [authRepositoryProvider.overrideWithValue(repository)],
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('intro_sign_in')).hitTestable(), findsOneWidget);
      expect(find.byKey(const ValueKey('intro_guest')).hitTestable(), findsOneWidget);
      expect(find.byKey(const ValueKey('login_username')), findsNothing);
      expect(tester.takeException(), isNull);
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/intro_$name.png'));
    }, tags: ['golden']);
  }
}
