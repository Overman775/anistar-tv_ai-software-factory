// Finder evaluation is repeated to observe widget replacement across auth transitions.
// ignore_for_file: prefer-moving-to-variable

import 'dart:async';

import 'package:anistar_tv/app/app.dart';
import 'package:anistar_tv/packages/features/auth/auth_providers.dart';
import 'package:anistar_tv/packages/features/auth/domain/auth_invalid_credentials_failure.dart';
import 'package:anistar_tv/packages/features/auth/presentation/login_screen.dart';
import 'package:anistar_tv/packages/features/catalog/catalog_providers.dart';
import 'package:anistar_tv/packages/features/catalog/presentation/screens/catalog_screen.dart';
import 'package:core/data.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:networking/networking.dart';
import 'package:ui_kit/ui_kit.dart';

import '../../../mocks/features/auth/fake_auth_repository.dart';
import '../../../mocks/features/catalog/fake_catalog_screen_repository.dart';
import '../../../support/test_app.dart';

void main() {
  late FakeAuthRepository repository;
  setUp(() => repository = FakeAuthRepository());
  tearDown(() => repository.close());

  testWidgets('portrait login at 200% reveals remote fields and submit', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpTvApp(
      tester,
      const LoginScreen(),
      size: const Size(390, 844),
      wrapInScaffold: false,
      overrides: [authRepositoryProvider.overrideWithValue(repository)],
    );
    await tester.pumpAndSettle();
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    final username = find.byKey(const ValueKey('login_username'));
    final password = find.byKey(const ValueKey('login_password'));
    await tester.enterText(username, List.filled(30, 'ユーザー🎬').join());
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(password.hitTestable(), findsOneWidget);
    await tester.enterText(password, 'пароль🎬');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    final submit = find.byKey(const ValueKey('login_submit'));
    expect(submit.hitTestable(), findsOneWidget);
    expect(tester.getRect(submit).bottom, lessThanOrEqualTo(564));
    expect(tester.takeException(), isNull);
  });

  testWidgets('ten rapid submissions leave one pending login and clear password only after failure', (tester) async {
    final pending = Completer<Result<String, Failure>>();
    repository.pendingLogin = pending;
    await pumpTvApp(
      tester,
      const LoginScreen(),
      wrapInScaffold: false,
      overrides: [authRepositoryProvider.overrideWithValue(repository)],
    );
    await tester.pumpAndSettle();
    final password = find.byKey(const ValueKey('login_password'));
    await tester.enterText(find.byKey(const ValueKey('login_username')), 'test');
    await tester.enterText(password, 'secret');
    final submit = find.byKey(const ValueKey('login_submit'));
    final send = tester.widget<AppButton>(submit).onPressed;
    for (var i = 0; i < 10; i++) {
      send();
    }
    await tester.pump();
    expect(repository.loginCalls, 1);
    expect(tester.widget<AppButton>(submit).busy, isTrue);
    expect(tester.widget<TextFormField>(password).controller?.text, 'secret');
    pending.complete(const Result.failure(AuthInvalidCredentialsFailure()));
    await tester.pumpAndSettle();
    expect(tester.widget<TextFormField>(password).controller?.text, isEmpty);
    expect(tester.widget<AppButton>(submit).busy, isFalse);
    expect(tester.takeException(), isNull);
  });

  for (final failure in <Failure>[const ConnectionFailure(), const ServerFailure(), const UnknownFailure()]) {
    testWidgets('a ${failure.runtimeType} preserves both login fields', (tester) async {
      repository.loginResult = Result.failure(failure);
      await pumpTvApp(
        tester,
        const LoginScreen(),
        wrapInScaffold: false,
        overrides: [authRepositoryProvider.overrideWithValue(repository)],
      );
      await tester.pumpAndSettle();
      final username = find.byKey(const ValueKey('login_username'));
      final password = find.byKey(const ValueKey('login_password'));
      await tester.enterText(username, 'retained-user');
      await tester.enterText(password, 'retained-input');
      await tester.tap(find.byKey(const ValueKey('login_submit')));
      await tester.pumpAndSettle();
      expect(tester.widget<TextFormField>(username).controller?.text, 'retained-user');
      expect(tester.widget<TextFormField>(password).controller?.text, 'retained-input');
      expect(repository.loginCalls, 1);
      expect(find.textContaining('Гост'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

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
    repository.loginResult = const Result.failure(AuthInvalidCredentialsFailure());
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
    expect(find.text(const AuthInvalidCredentialsFailure().message), findsOneWidget);
  });

  testWidgets('restore focuses username and rejected login returns focus to password for remote retry', (tester) async {
    final semantics = tester.ensureSemantics();
    repository.loginResult = const Result.failure(AuthInvalidCredentialsFailure());
    await pumpTvApp(
      tester,
      const LoginScreen(),
      wrapInScaffold: false,
      overrides: [authRepositoryProvider.overrideWithValue(repository)],
    );
    await tester.pumpAndSettle();
    final username = find.byKey(const ValueKey('login_username'));
    final password = find.byKey(const ValueKey('login_password'));
    final field = find.byType(EditableText);
    expect(tester.widget<EditableText>(find.descendant(of: username, matching: field)).focusNode.hasFocus, isTrue);
    await tester.enterText(username, 'test');
    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pumpAndSettle();
    expect(tester.widget<EditableText>(find.descendant(of: password, matching: field)).focusNode.hasFocus, isTrue);
    await tester.enterText(password, 'secret');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(repository.loginCalls, 1);
    final error = tester.getSemantics(find.byKey(const ValueKey('login_error'))).getSemanticsData();
    expect(error.flagsCollection.isLiveRegion, isTrue);
    expect(error.label, contains(const AuthInvalidCredentialsFailure().message));
    // Focus is checked again after a separate, rejected network operation.
    // ignore: avoid-duplicate-test-assertions
    expect(tester.widget<EditableText>(find.descendant(of: password, matching: field)).focusNode.hasFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(
      FocusManager.instance.primaryFocus?.context?.findAncestorWidgetOfExactType<AppButton>()?.key,
      const ValueKey('login_submit'),
    );
    semantics.dispose();
  });

  testWidgets('arrows keep both populated fields editable through rejection and a second attempt', (tester) async {
    repository.loginResult = const Result.failure(AuthInvalidCredentialsFailure());
    await pumpTvApp(
      tester,
      const LoginScreen(),
      wrapInScaffold: false,
      overrides: [authRepositoryProvider.overrideWithValue(repository)],
    );
    await tester.pumpAndSettle();
    final username = find.byKey(const ValueKey('login_username'));
    final password = find.byKey(const ValueKey('login_password'));
    final submit = find.byKey(const ValueKey('login_submit'));
    final usernameNode = tester
        .widget<EditableText>(find.descendant(of: username, matching: find.byType(EditableText)))
        .focusNode;
    final passwordNode = tester
        .widget<EditableText>(find.descendant(of: password, matching: find.byType(EditableText)))
        .focusNode;
    final submitNode = tester.widget<AppButton>(submit).focusNode;
    await tester.enterText(username, 'test');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(FocusManager.instance.primaryFocus, same(passwordNode));
    await tester.enterText(password, 'wrong');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(FocusManager.instance.primaryFocus, same(submitNode));
    await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();
    // Recheck the same target after the explicit reverse transition from submit.
    // ignore: avoid-duplicate-test-assertions
    expect(FocusManager.instance.primaryFocus, same(passwordNode));
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.arrowUp);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();
    expect(FocusManager.instance.primaryFocus, same(usernameNode));
    for (var attempt = 0; attempt < 2; attempt++) {
      await tester.enterText(username, 'test$attempt');
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      await tester.enterText(password, 'wrong$attempt');
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      expect(tester.widget<TextFormField>(password).controller?.selection.baseOffset, 5);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pumpAndSettle();
      expect(repository.loginCalls, attempt + 1);
      expect(FocusManager.instance.primaryFocus, same(passwordNode));
      expect(tester.widget<TextFormField>(password).controller?.text, isEmpty);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();
      expect(FocusManager.instance.primaryFocus, same(usernameNode));
    }
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
      ..logoutResult = const Result.failure(AuthInvalidCredentialsFailure());
    final container = ProviderContainer(overrides: [authRepositoryProvider.overrideWithValue(repository)]);
    addTearDown(container.dispose);
    await container.read(authControllerProvider.future);
    expect(await container.read(authControllerProvider.notifier).signOut(), isA<Failure>());
    expect(container.read(authControllerProvider).asData?.value, 'test');
  });
}
