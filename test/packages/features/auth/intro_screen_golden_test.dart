import 'package:anistar_tv/packages/features/auth/auth_providers.dart';
import 'package:anistar_tv/packages/features/auth/presentation/intro_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../../mocks/features/auth/fake_auth_repository.dart';
import '../../../support/test_app.dart';

void main() {
  testWidgets('intro panel at the common TV profile', (tester) async {
    final repository = FakeAuthRepository();
    addTearDown(repository.close);
    await testScreenGolden(
      tester,
      'intro',
      screen: const IntroScreen(),
      wrapInScaffold: false,
      overrides: [authRepositoryProvider.overrideWithValue(repository)],
      prepare: (tester) async {
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('intro_sign_in')).hitTestable(), findsOneWidget);
        expect(find.byKey(const ValueKey('intro_guest')).hitTestable(), findsOneWidget);
        expect(find.byKey(const ValueKey('login_username')), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }, tags: ['golden']);
}
