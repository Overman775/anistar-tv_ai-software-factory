import 'dart:async';

import 'package:anistar_tv/packages/features/auth/auth_providers.dart';
import 'package:anistar_tv/packages/features/auth/domain/auth_repository.dart';
import 'package:core/data.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:networking/networking.dart';

void main() {
  group('AuthProfileController', () {
    test('confirmed restore loads the default profile once without changing access', () async {
      final repository = _ProfileAuthRepository()..restoreResult = const Result.success('viewer');
      final container = _container(repository);
      AuthAccess observedAccess = const UnknownAccess();
      final accessSubscription = container.listen<AuthAccess>(
        authAccessProvider,
        (_, access) => observedAccess = access,
        fireImmediately: true,
      );
      addTearDown(() async {
        accessSubscription.close();
        container.dispose();
        await repository.close();
      });

      await container.read(authControllerProvider.future);
      final loading = container.read(authProfileStateProvider);
      expect(repository.profileAccounts, ['viewer']);
      expect(loading.loadState, AuthProfileLoadState.loading);
      expect(loading.profile, isNull);
      final restoredAccess = container.read(authAccessProvider);
      expect(restoredAccess, isA<AuthenticatedAccess>());

      repository.profileRequests.single.complete(const Result.success(AuthProfile()));
      await _drain();
      final loaded = container.read(authProfileStateProvider);
      expect(loaded.loadState, AuthProfileLoadState.loaded);
      expect(loaded.account, 'viewer');
      expect(loaded.profile?.imageUri, isNull);
      final loadedAccess = container.read(authAccessProvider);
      expect(loadedAccess.account, 'viewer');
      expect(observedAccess.account, 'viewer');
    });

    test('successful sign-in starts one profile request and keeps login access independent of metadata', () async {
      final repository = _ProfileAuthRepository()..loginResult = const Result.success('signed-in');
      final container = _container(repository);
      AuthAccess observedAccess = const UnknownAccess();
      final accessSubscription = container.listen<AuthAccess>(
        authAccessProvider,
        (_, access) => observedAccess = access,
        fireImmediately: true,
      );
      addTearDown(() async {
        accessSubscription.close();
        container.dispose();
        await repository.close();
      });

      await container.read(authControllerProvider.future);
      final auth = container.read(authControllerProvider.notifier)..requestSignIn();
      await auth.signIn('signed-in', 'fixture-password');

      expect(repository.profileAccounts, ['signed-in']);
      final signedInAccess = container.read(authAccessProvider);
      final loading = container.read(authProfileStateProvider);
      expect(signedInAccess.account, 'signed-in');
      expect(observedAccess.account, 'signed-in');
      expect(loading.loadState, AuthProfileLoadState.loading);
      repository.profileRequests.single.complete(const Result.failure(ConnectionFailure()));
      await _drain();
      final failed = container.read(authProfileStateProvider);
      expect(failed.loadState, AuthProfileLoadState.failed);
      expect(failed.profile, isNull);
      expect(failed.failure, isA<ConnectionFailure>());
      final failedAccess = container.read(authAccessProvider);
      expect(failedAccess.account, 'signed-in');
    });

    test('late account, origin and request results cannot replace the active profile context', () async {
      final repository = _ProfileAuthRepository();
      final container = _container(repository);
      addTearDown(() async {
        container.dispose();
        await repository.close();
      });
      final controller = container.read(authProfileStateProvider.notifier);
      final firstOrigin = Uri.parse('https://one.test/');
      final secondOrigin = Uri.parse('https://two.test/');
      final profileRequests = repository.profileRequests;

      controller.load(account: 'first', origin: firstOrigin, contextGeneration: 1);
      repository.profileOrigin = secondOrigin;
      controller.load(account: 'second', origin: secondOrigin, contextGeneration: 2);
      expect(profileRequests, hasLength(2));
      expect(repository.profileAccounts, ['first', 'second']);

      profileRequests.first.complete(
        Result.success(AuthProfile(imageUri: Uri.parse('https://one.test/uploads/fotos/first.jpeg'))),
      );
      await _drain();
      final current = container.read(authProfileStateProvider);
      expect(current.loadState, AuthProfileLoadState.loading);
      expect(current.account, 'second');
      expect(current.origin, secondOrigin);
      expect(current.contextGeneration, 2);

      profileRequests.last.complete(const Result.success(AuthProfile()));
      await _drain();
      final loaded = container.read(authProfileStateProvider);
      expect(loaded.account, 'second');
      expect(loaded.profile?.imageUri, isNull);

      controller.load(account: 'third', origin: secondOrigin, contextGeneration: 3);
      repository.profileOrigin = Uri.parse('https://changed-origin.test/');
      profileRequests.last.complete(
        Result.success(AuthProfile(imageUri: Uri.parse('https://two.test/uploads/fotos/third.jpeg'))),
      );
      await _drain();
      final staleOrigin = container.read(authProfileStateProvider);
      expect(staleOrigin.loadState, AuthProfileLoadState.loading);
      expect(staleOrigin.account, 'third');
      expect(staleOrigin.profile, isNull);
    });

    test('logout and expiry synchronously clear a pending profile and suppress its late result', () async {
      for (final expire in [false, true]) {
        final repository = _ProfileAuthRepository()..restoreResult = const Result.success('viewer');
        final container = _container(repository);
        final accessSubscription = container.listen<AuthAccess>(
          authAccessProvider,
          (_, next) => next,
          fireImmediately: true,
        );
        addTearDown(() async {
          accessSubscription.close();
          container.dispose();
          await repository.close();
        });

        await container.read(authControllerProvider.future);
        final pending = repository.profileRequests.single;
        if (expire) {
          repository.expire();
          await _drain();
        } else {
          await container.read(authControllerProvider.notifier).signOut();
        }
        final cleared = container.read(authProfileStateProvider);
        _expectInactive(cleared);
        expect(container.read(authAccessProvider), isA<UnauthenticatedAccess>());

        pending.complete(
          Result.success(AuthProfile(imageUri: Uri.parse('https://profiles.test/uploads/fotos/viewer.jpeg'))),
        );
        await _drain();
        final afterLateResult = container.read(authProfileStateProvider);
        _expectInactive(afterLateResult);
      }
    });
  });
}

ProviderContainer _container(_ProfileAuthRepository repository) =>
    ProviderContainer(overrides: [authRepositoryProvider.overrideWithValue(repository)]);

Future<void> _drain() => Future<void>.delayed(Duration.zero);

void _expectInactive(AuthProfileState state) {
  expect(state.loadState, AuthProfileLoadState.inactive);
  expect(state.account, isNull);
  expect(state.profile, isNull);
}

// The controlled AuthRepository double belongs only to this lifecycle test.
// ignore: prefer-match-file-name
final class _ProfileAuthRepository implements AuthRepository {
  Result<String?, Failure> restoreResult = const Result.success(null);
  Result<String, Failure> loginResult = const Result.success('viewer');
  Result<void, Failure> logoutResult = const Result.success(null);
  @override
  Uri profileOrigin = Uri.parse('https://profiles.test/');
  final List<String> profileAccounts = [];
  final List<Completer<Result<AuthProfile, Failure>>> profileRequests = [];
  final StreamController<void> _expired = StreamController<void>.broadcast();

  @override
  Stream<void> get expired => _expired.stream;

  @override
  Future<Result<void, Failure>> cancelSignIn(RequestCancellation cancellation) {
    cancellation.cancel();

    return Future.value(const Result.success(null));
  }

  @override
  Future<Result<AuthProfile, Failure>> loadProfile(String account) {
    profileAccounts.add(account);
    final request = Completer<Result<AuthProfile, Failure>>();
    profileRequests.add(request);

    return request.future;
  }

  @override
  Future<Result<String?, Failure>> restore({void Function()? onSessionCheck}) {
    onSessionCheck?.call();

    return Future.value(restoreResult);
  }

  @override
  Future<Result<String, Failure>> signIn(String username, String password, {RequestCancellation? cancellation}) =>
      Future.value(loginResult);

  @override
  Future<Result<void, Failure>> signOut() => Future.value(logoutResult);

  void expire() => _expired.add(null);

  Future<void> close() => _expired.close();
}
