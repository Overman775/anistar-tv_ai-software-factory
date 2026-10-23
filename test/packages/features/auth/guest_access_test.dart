import 'dart:async';

import 'package:anistar_tv/packages/features/auth/auth_providers.dart';
import 'package:core/data.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../mocks/features/auth/fake_auth_repository.dart';

void main() {
  test('startup and absent session are not implicit anonymous access', () async {
    final pending = Completer<Result<String?, Failure>>();
    final repository = FakeAuthRepository()..pendingRestore = pending;
    addTearDown(repository.close);
    final container = ProviderContainer(overrides: [authRepositoryProvider.overrideWithValue(repository)]);
    addTearDown(container.dispose);
    expect(container.read(authAccessProvider), isA<UnknownAccess>());
    container.read(authControllerProvider.notifier).enterAnonymous();
    expect(container.read(authAccessProvider).canBrowse, isFalse);
    pending.complete(const Result.success(null));
    await container.read(authControllerProvider.future);
    final access = container.read(authAccessProvider);
    expect(access, isA<UnauthenticatedAccess>());
    expect(access.canBrowse, isFalse);
    expect(access.canUseAccount, isFalse);
  });

  test('explicit guest choice grants public capabilities but no account capability or persisted login', () async {
    final repository = FakeAuthRepository();
    addTearDown(repository.close);
    final override = authRepositoryProvider.overrideWithValue(repository);
    final container = ProviderContainer(overrides: [override]);
    addTearDown(container.dispose);
    await container.read(authControllerProvider.future);
    container.read(authControllerProvider.notifier).enterAnonymous();
    final access = container.read(authAccessProvider);
    expect(access, isA<AnonymousAccess>());
    expect(access.account, isNull);
    expect(access.canBrowse, isTrue);
    expect(access.canUseAccount, isFalse);
    expect(repository.loginCalls, 0);
    final restarted = ProviderContainer(overrides: [override]);
    addTearDown(restarted.dispose);
    expect((await restarted.read(authControllerProvider.future)).access, isA<UnauthenticatedAccess>());
  });

  test('cancelled guest login preserves guest access and rejects late confirmation', () async {
    final pending = Completer<Result<String, Failure>>();
    final repository = FakeAuthRepository()..pendingLogin = pending;
    addTearDown(repository.close);
    final container = ProviderContainer(overrides: [authRepositoryProvider.overrideWithValue(repository)]);
    addTearDown(container.dispose);
    await container.read(authControllerProvider.future);
    final controller = container.read(authControllerProvider.notifier)
      ..enterAnonymous()
      ..requestSignIn();
    final operation = controller.signIn('viewer', 'fixture-password');
    // This snapshot precedes cancellation; the later snapshot must sample again.
    // ignore: prefer-moving-to-variable
    final submitting = container.read(authControllerProvider).value;
    expect(submitting?.isSigningIn, isTrue);
    expect(container.read(authAccessProvider), isA<AnonymousAccess>());
    await controller.signIn('duplicate', 'fixture-password');
    expect(repository.loginCalls, 1);
    final cancellation = repository.lastLoginCancellation;
    final cancellationOperation = controller.cancelSignIn();
    pending.complete(const Result.success('late-account'));
    await operation;
    await cancellationOperation;
    // Cancellation must re-read the provider after the pending operation completes.
    // ignore: prefer-moving-to-variable
    final current = container.read(authControllerProvider).value ?? (throw TestFailure('Expected restored auth state'));
    expect(cancellation?.isCancelled, isTrue);
    expect(current.access, same(submitting?.access));
    expect(current.loginRequested, isFalse);
    expect(current.isSigningIn, isFalse);
    expect(current.signInFailure, isNull);
  });

  test('failed guest login retains the guest and return intent, while success grants the confirmed account', () async {
    final repository = FakeAuthRepository()..loginResult = const Result.failure(UnknownFailure());
    addTearDown(repository.close);
    final container = ProviderContainer(overrides: [authRepositoryProvider.overrideWithValue(repository)]);
    addTearDown(container.dispose);
    await container.read(authControllerProvider.future);
    final controller = container.read(authControllerProvider.notifier)
      ..enterAnonymous()
      ..requestSignIn();
    const username = 'viewer';
    const password = 'fixture-password';
    await controller.signIn(username, password);
    // This snapshot precedes retry; the later snapshot must sample again.
    // ignore: prefer-moving-to-variable
    final failed = container.read(authControllerProvider).value ?? (throw TestFailure('Expected restored auth state'));
    expect(failed.access, isA<AnonymousAccess>());
    expect(failed.loginRequested, isTrue);
    expect(failed.isSigningIn, isFalse);
    expect(failed.signInFailure, isA<UnknownFailure>());
    repository.loginResult = const Result.success('viewer');
    await controller.signIn(username, password);
    final access = container.read(authAccessProvider);
    expect(access, isA<AuthenticatedAccess>());
    expect(access.account, 'viewer');
    expect(access.canUseAccount, isTrue);
    // Successful retry must sample the state after the account transition.
    // ignore: prefer-moving-to-variable
    expect(container.read(authControllerProvider).value?.loginRequested, isFalse);
  });

  test('logout and expiry return to unauthenticated access without choosing guest', () async {
    for (final expired in [false, true]) {
      final repository = FakeAuthRepository()..restoreResult = const Result.success('viewer');
      final container = ProviderContainer(overrides: [authRepositoryProvider.overrideWithValue(repository)]);
      await container.read(authControllerProvider.future);
      if (expired) {
        repository.expire();
        await Future<void>.delayed(Duration.zero);
      } else {
        await container.read(authControllerProvider.notifier).signOut();
      }
      expect(container.read(authAccessProvider), isA<UnauthenticatedAccess>());
      container.dispose();
      await repository.close();
    }
  });

  test('failed restoration never enables the explicit guest action', () async {
    final repository = FakeAuthRepository()..restoreResult = const Result.failure(UnknownFailure());
    addTearDown(repository.close);
    final container = ProviderContainer(overrides: [authRepositoryProvider.overrideWithValue(repository)]);
    addTearDown(container.dispose);
    await expectLater(container.read(authControllerProvider.future), throwsA(isA<UnknownFailure>()));
    container.read(authControllerProvider.notifier).enterAnonymous();
    expect(container.read(authAccessProvider), isA<UnknownAccess>());
    expect(container.read(authStartupStageProvider), isNot(AuthStartupStage.complete));
  });
}
