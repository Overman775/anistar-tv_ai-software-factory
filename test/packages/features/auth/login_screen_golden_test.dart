import 'package:anistar_tv/packages/features/auth/auth_providers.dart';
import 'package:anistar_tv/packages/features/auth/presentation/login_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../../mocks/features/auth/fake_auth_repository.dart';
import '../../../support/test_app.dart';

void main() {
  for (final (name, size) in [('compact', compactTvSize), ('wide', wideTvSize)]) {
    testWidgets('login panel at $name viewport', (tester) async {
      final repository = FakeAuthRepository();
      addTearDown(repository.close);
      await pumpTvApp(
        tester,
        const LoginScreen(),
        size: size,
        wrapInScaffold: false,
        overrides: [authRepositoryProvider.overrideWithValue(repository)],
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(tester.getBottomRight(find.byKey(const ValueKey('login_submit'))).dy, lessThan(size.height));
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/login_$name.png'));
    }, tags: ['golden']);
  }
}
