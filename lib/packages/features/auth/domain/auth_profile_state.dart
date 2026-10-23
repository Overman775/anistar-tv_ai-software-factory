import 'package:core/data.dart';
import 'package:meta/meta.dart';

import 'auth_profile.dart';
import 'auth_profile_load_state.dart';

/// Profile metadata is scoped to the authenticated account context.
///
/// [contextGeneration] changes when Auth confirms a new account context. A
/// future adapter must retain it while loading and discard a result for a
/// different account context.
@immutable
final class AuthProfileState {
  final String? account;
  final int contextGeneration;
  final AuthProfileLoadState loadState;
  final AuthProfile? profile;
  final Failure? failure;

  const AuthProfileState._({
    required this.account,
    required this.contextGeneration,
    required this.loadState,
    this.profile,
    this.failure,
  });

  const AuthProfileState.inactive()
    : this._(account: null, contextGeneration: 0, loadState: AuthProfileLoadState.inactive);

  const AuthProfileState.unavailable({required String account, required int contextGeneration})
    : this._(account: account, contextGeneration: contextGeneration, loadState: AuthProfileLoadState.unavailable);

  const AuthProfileState.loading({required String account, required int contextGeneration})
    : this._(account: account, contextGeneration: contextGeneration, loadState: AuthProfileLoadState.loading);

  const AuthProfileState.loaded({required String account, required int contextGeneration, required AuthProfile profile})
    : this._(
        account: account,
        contextGeneration: contextGeneration,
        loadState: AuthProfileLoadState.loaded,
        profile: profile,
      );

  const AuthProfileState.failed({required String account, required int contextGeneration, required Failure failure})
    : this._(
        account: account,
        contextGeneration: contextGeneration,
        loadState: AuthProfileLoadState.failed,
        failure: failure,
      );
}
