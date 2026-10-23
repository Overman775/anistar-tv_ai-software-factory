import 'dart:async';

import 'package:core/data.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_repository_provider.dart';
import 'auth_startup_stage.dart';
import 'domain/auth_access.dart';

final class AuthController extends AsyncNotifier<AuthSessionState> {
  int _operation = 0;
  RequestCancellation? _signInCancellation;

  @override
  Future<AuthSessionState> build() async {
    final operation = ++_operation;
    final repository = ref.watch(authRepositoryProvider);
    final subscription = repository.expired.listen((_) {
      if (state.value?.requiresCancellation == true) {
        return;
      }
      final contextGeneration = ++_operation;
      _signInCancellation?.cancel();
      if (ref.read(authStartupStageProvider) != AuthStartupStage.complete) {
        ref.invalidateSelf();

        return;
      }
      state = AsyncData(AuthSessionState(const UnauthenticatedAccess(), profileContextGeneration: contextGeneration));
    });
    ref.onDispose(() {
      _signInCancellation?.cancel();
      unawaited(subscription.cancel());
    });
    // Avoid writing another provider while the App is being built.
    await Future<void>.value();
    if (!ref.mounted || operation != _operation) {
      return const AuthSessionState(UnknownAccess());
    }
    ref.read(authStartupStageProvider.notifier).stage = AuthStartupStage.site;
    final result = await repository.restore(
      onSessionCheck: () {
        if (ref.mounted && operation == _operation) {
          ref.read(authStartupStageProvider.notifier).stage = AuthStartupStage.session;
        }
      },
    );
    if (!ref.mounted || operation != _operation) {
      return const AuthSessionState(UnknownAccess());
    }

    return result.when(
      success: (account) {
        ref.read(authStartupStageProvider.notifier).stage = AuthStartupStage.complete;

        return AuthSessionState(
          account == null ? const UnauthenticatedAccess() : AuthenticatedAccess(account),
          profileContextGeneration: operation,
        );
      },
      failure: (failure) => throw failure,
    );
  }

  void enterAnonymous() {
    if (state.value?.access is! UnauthenticatedAccess ||
        state.isLoading ||
        ref.read(authStartupStageProvider) != AuthStartupStage.complete) {
      return;
    }
    final operation = ++_operation;
    state = AsyncData(AuthSessionState(const AnonymousAccess(), profileContextGeneration: operation));
  }

  void requestSignIn() {
    final session = state.value;
    if (session == null ||
        (session.access is! AnonymousAccess && session.access is! UnauthenticatedAccess) ||
        state.isLoading ||
        session.requiresCancellation) {
      return;
    }
    state = AsyncData(
      AuthSessionState(
        session.access,
        loginRequested: true,
        profileContextGeneration: session.profileContextGeneration,
      ),
    );
  }

  Future<void> cancelSignIn() async {
    final previous = state.value;
    if (previous == null ||
        (previous.access is! AnonymousAccess && previous.access is! UnauthenticatedAccess) ||
        previous.isCancellingSignIn) {
      return;
    }
    final operation = ++_operation;
    final cancellation = _signInCancellation;
    if (cancellation == null) {
      state = AsyncData(AuthSessionState(previous.access, profileContextGeneration: previous.profileContextGeneration));

      return;
    }
    state = AsyncData(
      AuthSessionState(
        previous.access,
        loginRequested: true,
        operation: AuthOperation.cancellingSignIn,
        profileContextGeneration: previous.profileContextGeneration,
      ),
    );
    cancellation.cancel();
    final result = await ref.read(authRepositoryProvider).cancelSignIn(cancellation);
    if (!ref.mounted || operation != _operation) {
      return;
    }
    result.when(
      success: (_) {
        _signInCancellation = null;
        state = AsyncData(
          AuthSessionState(previous.access, profileContextGeneration: previous.profileContextGeneration),
        );
      },
      failure: (failure) {
        state = AsyncData(
          AuthSessionState(
            previous.access,
            loginRequested: true,
            operation: AuthOperation.cancellationFailed,
            cancellationFailure: failure,
            profileContextGeneration: previous.profileContextGeneration,
          ),
        );
      },
    );
  }

  Future<void> signIn(String username, String password) async {
    if (state.isLoading || state.value?.isSigningIn == true || state.value?.requiresCancellation == true) {
      return;
    }
    final previous = state.value ?? const AuthSessionState(UnauthenticatedAccess());
    final operation = ++_operation;
    final cancellation = _signInCancellation = RequestCancellation();
    state = AsyncData(
      AuthSessionState(
        previous.access,
        loginRequested: previous.loginRequested,
        operation: AuthOperation.signingIn,
        profileContextGeneration: previous.profileContextGeneration,
      ),
    );
    final result = await ref.read(authRepositoryProvider).signIn(username, password, cancellation: cancellation);
    if (!ref.mounted || operation != _operation || cancellation.isCancelled) {
      return;
    }
    _signInCancellation = null;
    state = result.when(
      success: (account) =>
          AsyncData(AuthSessionState(AuthenticatedAccess(account), profileContextGeneration: operation)),
      failure: (failure) => AsyncData(
        AuthSessionState(
          previous.access,
          loginRequested: previous.loginRequested,
          signInFailure: failure,
          profileContextGeneration: previous.profileContextGeneration,
        ),
      ),
    );
  }

  Future<Failure?> signOut() async {
    if (state.value?.requiresCancellation == true) {
      return state.value?.cancellationFailure ?? const UnknownFailure();
    }
    final operation = ++_operation;
    final result = await ref.read(authRepositoryProvider).signOut();
    if (!ref.mounted || operation != _operation) {
      return null;
    }

    return result.when(
      success: (_) {
        state = AsyncData(AuthSessionState(const UnauthenticatedAccess(), profileContextGeneration: operation));

        return null;
      },
      failure: (failure) => failure,
    );
  }

  void retryRestore() {
    if (state.isLoading || state.value?.isSigningIn == true || state.value?.requiresCancellation == true) {
      return;
    }
    ref.read(authStartupStageProvider.notifier).stage = AuthStartupStage.site;
    ref.invalidateSelf();
  }
}
