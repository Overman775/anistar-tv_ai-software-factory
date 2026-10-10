// Finder evaluation is repeated to observe widget replacement across auth transitions.
// ignore_for_file: prefer-moving-to-variable

import 'dart:async';

import 'package:anistar_tv/app/app.dart';
import 'package:anistar_tv/packages/features/auth/auth_providers.dart';
import 'package:anistar_tv/packages/features/auth/presentation/login_screen.dart';
import 'package:anistar_tv/packages/features/catalog/catalog_providers.dart';
import 'package:anistar_tv/packages/features/catalog/presentation/screens/catalog_screen.dart';
import 'package:core/data.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../../mocks/features/auth/fake_auth_repository.dart';
import '../../../mocks/features/catalog/fake_catalog_screen_repository.dart';
import '../../../support/test_app.dart';

void main() {
  late FakeAuthRepository repository;
  setUp(() => repository = FakeAuthRepository());
  tearDown(() => repository.close());

  testWidgets('anonymous launch is gated; login opens catalog; expiry destroys protected navigation', (tester) async {
    await pumpTvApp(
      tester,
      const App(),
      wrapInScaffold: false,
      overrides: [
        authRepositoryProvider.overrideWithValue(repository),
        catalogRepositoryProvider.overrideWithValue(const FakeCatalogScreenRepository()),
      ],
    );
    final settle = tester.pumpAndSettle;
    await settle();
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(CatalogScreen), findsNothing);
    final username = find.byKey(const ValueKey('login_username'));
    final password = find.byKey(const ValueKey('login_password'));
    await tester.enterText(username, 'test');
    await tester.enterText(password, 'secret');
    expect(
      tester.widget<TextField>(find.descendant(of: password, matching: find.byType(TextField))).obscureText,
      isTrue,
    );
    await tester.tap(find.byKey(const ValueKey('login_submit')));
    await settle();
    expect(find.byType(CatalogScreen), findsOneWidget);
    repository.expire();
    await settle();
    // Recheck the gate after an authenticated router existed.
    // ignore: avoid-duplicate-test-assertions
    expect(find.byType(LoginScreen), findsOneWidget);
    // The catalog was present before expiry.
    // ignore: avoid-duplicate-test-assertions
    expect(find.byType(CatalogScreen), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('login validates inputs, rejects safely and clears the password', (tester) async {
    repository.loginResult = const Result.failure(UnknownFailure());
    await pumpTvApp(
      tester,
      const LoginScreen(),
      wrapInScaffold: false,
      overrides: [authRepositoryProvider.overrideWithValue(repository)],
    );
    final settle = tester.pumpAndSettle;
    await settle();
    final submit = find.byKey(const ValueKey('login_submit'));
    await tester.tap(submit);
    await settle();
    expect(repository.loginCalls, 0);
    await tester.enterText(find.byKey(const ValueKey('login_username')), 'test');
    final password = find.byKey(const ValueKey('login_password'));
    await tester.enterText(password, 'secret');
    await tester.tap(find.byTooltip('Показать пароль'));
    await tester.pump();
    expect(
      tester.widget<TextField>(find.descendant(of: password, matching: find.byType(TextField))).obscureText,
      isFalse,
    );
    await tester.tap(find.byTooltip('Скрыть пароль'));
    await tester.pump();
    expect(
      tester.widget<TextField>(find.descendant(of: password, matching: find.byType(TextField))).obscureText,
      isTrue,
    );
    await tester.tap(submit);
    await settle();
    expect(repository.loginCalls, 1);
    expect(tester.widget<TextFormField>(password).controller?.text, isEmpty);
    expect(find.text(const UnknownFailure().message), findsOneWidget);
  });

  test('concurrent login is blocked; expiry prevents a late login result from unlocking the app', () async {
    repository.pendingLogin = Completer<Result<String, Failure>>();
    final container = ProviderContainer(overrides: [authRepositoryProvider.overrideWithValue(repository)]);
    addTearDown(container.dispose);
    await container.read(authControllerProvider.future);
    final controller = container.read(authControllerProvider.notifier);
    final first = controller.signIn('test', 'secret');
    await controller.signIn('test', 'secret');
    expect(repository.loginCalls, 1);
    repository.expire();
    await Future<void>.delayed(Duration.zero);
    repository.pendingLogin?.complete(const Result.success('test'));
    await first;
    expect(container.read(authControllerProvider).asData?.value, isNull);
  });

  test('failed secure deletion keeps the authenticated gate and returns an error', () async {
    repository
      ..restoreResult = const Result.success('test')
      ..logoutResult = const Result.failure(UnknownFailure());
    final container = ProviderContainer(overrides: [authRepositoryProvider.overrideWithValue(repository)]);
    addTearDown(container.dispose);
    await container.read(authControllerProvider.future);
    expect(await container.read(authControllerProvider.notifier).signOut(), isA<Failure>());
    expect(container.read(authControllerProvider).asData?.value, 'test');
  });
}
