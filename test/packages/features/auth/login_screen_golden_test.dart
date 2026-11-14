import 'package:anistar_tv/packages/features/auth/auth_providers.dart';
import 'package:anistar_tv/packages/features/auth/presentation/login_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../../mocks/features/auth/fake_auth_repository.dart';
import '../../../support/test_app.dart';

void main() {
  testWidgets('login panel at the common TV profile', (tester) async {
    final repository = FakeAuthRepository();
    addTearDown(repository.close);
    await testScreenGolden(
      tester,
      'login',
      screen: const LoginScreen(),
      wrapInScaffold: false,
      overrides: [authRepositoryProvider.overrideWithValue(repository)],
      prepare: (tester) async {
        await tester.pumpAndSettle();
        expect(
          tester.getBottomRight(find.byKey(const ValueKey('login_submit'))).dy,
          lessThan(GoldenProfile.tv.logicalSize.height),
        );
      },
    );
  }, tags: ['golden']);
}
