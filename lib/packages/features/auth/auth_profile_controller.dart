import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_repository_provider.dart';
import 'domain/auth_profile_state.dart';

/// Owns one metadata load for each confirmed account/origin/auth generation.
final authProfileStateProvider = NotifierProvider<AuthProfileController, AuthProfileState>(AuthProfileController.new);

final class AuthProfileController extends Notifier<AuthProfileState> {
  int _requestGeneration = 0;

  @override
  AuthProfileState build() => const AuthProfileState.inactive();

  void clear() {
    _requestGeneration++;
    state = const AuthProfileState.inactive();
  }

  void unavailable({required String account, required int contextGeneration}) {
    _requestGeneration++;
    state = AuthProfileState.unavailable(account: account, contextGeneration: contextGeneration);
  }

  void load({required String account, required Uri origin, required int contextGeneration}) {
    final requestGeneration = ++_requestGeneration;
    state = AuthProfileState.loading(account: account, origin: origin, contextGeneration: contextGeneration);
    unawaited(
      _load(
        account: account,
        origin: origin,
        contextGeneration: contextGeneration,
        requestGeneration: requestGeneration,
      ),
    );
  }

  Future<void> _load({
    required String account,
    required Uri origin,
    required int contextGeneration,
    required int requestGeneration,
  }) async {
    final repository = ref.read(authRepositoryProvider);
    final result = await repository.loadProfile(account);
    if (!ref.mounted ||
        requestGeneration != _requestGeneration ||
        repository.profileOrigin != origin ||
        state.account != account ||
        state.origin != origin ||
        state.contextGeneration != contextGeneration) {
      return;
    }
    result.when(
      success: (profile) => state = AuthProfileState.loaded(
        account: account,
        origin: origin,
        contextGeneration: contextGeneration,
        profile: profile,
      ),
      failure: (failure) => state = AuthProfileState.failed(
        account: account,
        origin: origin,
        contextGeneration: contextGeneration,
        failure: failure,
      ),
    );
  }
}
