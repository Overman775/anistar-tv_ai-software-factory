import 'dart:async';

import 'package:core/data.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_repository_provider.dart';
import 'auth_startup_stage.dart';

final class AuthController extends AsyncNotifier<String?> {
  int _operation = 0;

  @override
  Future<String?> build() async {
    final operation = ++_operation;
    final repository = ref.watch(authRepositoryProvider);
    final subscription = repository.expired.listen((_) {
      _operation++;
      if (ref.read(authStartupStageProvider) != AuthStartupStage.complete) {
        ref.invalidateSelf();

        return;
      }
      state = const AsyncData(null);
    });
    ref.onDispose(() => unawaited(subscription.cancel()));
    // Avoid writing another provider while the App is being built.
    await Future<void>.value();
    if (!ref.mounted || operation != _operation) {
      return null;
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
      return null;
    }

    return result.when(
      success: (account) {
        ref.read(authStartupStageProvider.notifier).stage = AuthStartupStage.complete;

        return account;
      },
      failure: (failure) => throw failure,
    );
  }

  Future<void> signIn(String username, String password) async {
    if (state.isLoading) {
      return;
    }
    final operation = ++_operation;
    state = const AsyncLoading();
    final result = await ref.read(authRepositoryProvider).signIn(username, password);
    if (!ref.mounted || operation != _operation) {
      return;
    }
    state = result.when(success: AsyncData.new, failure: (failure) => AsyncError(failure, StackTrace.current));
  }

  Future<Failure?> signOut() async {
    final operation = ++_operation;
    final result = await ref.read(authRepositoryProvider).signOut();
    if (!ref.mounted || operation != _operation) {
      return null;
    }

    return result.when(
      success: (_) {
        state = const AsyncData(null);

        return null;
      },
      failure: (failure) => failure,
    );
  }

  void retryRestore() {
    if (state.isLoading) {
      return;
    }
    ref.read(authStartupStageProvider.notifier).stage = AuthStartupStage.site;
    ref.invalidateSelf();
  }
}
