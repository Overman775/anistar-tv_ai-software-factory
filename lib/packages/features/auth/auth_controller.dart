import 'dart:async';

import 'package:core/data.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_repository_provider.dart';

final class AuthController extends AsyncNotifier<String?> {
  int _operation = 0;

  @override
  Future<String?> build() async {
    _operation++;
    final repository = ref.watch(authRepositoryProvider);
    final subscription = repository.expired.listen((_) {
      _operation++;
      state = const AsyncData(null);
    });
    ref.onDispose(() => unawaited(subscription.cancel()));
    final result = await repository.restore();

    return result.when(success: (account) => account, failure: (failure) => throw failure);
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

  void retryRestore() => ref.invalidateSelf();
}
