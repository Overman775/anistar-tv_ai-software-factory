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
      _operation++;
      _signInCancellation?.cancel();
      if (ref.read(authStartupStageProvider) != AuthStartupStage.complete) {
        ref.invalidateSelf();

        return;
      }
      state = const AsyncData(AuthSessionState(UnauthenticatedAccess()));
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

        return AuthSessionState(account == null ? const UnauthenticatedAccess() : AuthenticatedAccess(account));
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
    _operation++;
    state = const AsyncData(AuthSessionState(AnonymousAccess()));
  }

  void requestSignIn() {
    final access = state.value?.access;
    if (access is AnonymousAccess && !state.isLoading && state.value?.requiresCancellation != true) {
      state = AsyncData(AuthSessionState(access, loginRequested: true));
    }
  }

  Future<void> cancelSignIn() async {
    final previous = state.value;
    if (previous?.access is! AnonymousAccess || previous?.isCancellingSignIn == true) {
      return;
    }
    final operation = ++_operation;
    final cancellation = _signInCancellation;
    if (cancellation == null) {
      state = const AsyncData(AuthSessionState(AnonymousAccess()));

      return;
    }
    state = const AsyncData(
      AuthSessionState(AnonymousAccess(), loginRequested: true, operation: AuthOperation.cancellingSignIn),
    );
    cancellation.cancel();
    final result = await ref.read(authRepositoryProvider).cancelSignIn(cancellation);
    if (!ref.mounted || operation != _operation) {
      return;
    }
    result.when(
      success: (_) {
        _signInCancellation = null;
        state = const AsyncData(AuthSessionState(AnonymousAccess()));
      },
      failure: (failure) {
        state = AsyncData(
          AuthSessionState(
            const AnonymousAccess(),
            loginRequested: true,
            operation: AuthOperation.cancellationFailed,
            cancellationFailure: failure,
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
      AuthSessionState(previous.access, loginRequested: previous.loginRequested, operation: AuthOperation.signingIn),
    );
    final result = await ref.read(authRepositoryProvider).signIn(username, password, cancellation: cancellation);
    if (!ref.mounted || operation != _operation || cancellation.isCancelled) {
      return;
    }
    _signInCancellation = null;
    state = result.when(
      success: (account) => AsyncData(AuthSessionState(AuthenticatedAccess(account))),
      failure: (failure) =>
          AsyncData(AuthSessionState(previous.access, loginRequested: previous.loginRequested, signInFailure: failure)),
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
        state = const AsyncData(AuthSessionState(UnauthenticatedAccess()));

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
