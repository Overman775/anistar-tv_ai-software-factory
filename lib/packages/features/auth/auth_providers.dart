import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_controller.dart';
import 'auth_startup_stage.dart';
import 'domain/auth_access.dart';
import 'domain/auth_profile_state.dart';

export 'auth_controller.dart';
export 'auth_repository_provider.dart';
export 'auth_startup_stage.dart';
export 'domain/auth_access.dart';
export 'domain/auth_profile.dart';
export 'domain/auth_profile_load_state.dart';
export 'domain/auth_profile_state.dart';

final authControllerProvider = AsyncNotifierProvider<AuthController, AuthSessionState>(
  AuthController.new,
  retry: (_, _) => null,
);

final authAccessProvider = Provider<AuthAccess>((ref) {
  final auth = ref.watch(authControllerProvider);
  if (ref.watch(authStartupStageProvider) != AuthStartupStage.complete || auth.isLoading) {
    return const UnknownAccess();
  }

  return auth.value?.access ?? const UnknownAccess();
});

/// A source-independent profile seam while EXT-01 is unverified.
///
/// No metadata request is started here. Once AniStar profile markup and its
/// safe delivery contract are evidenced, its loader must use the account and
/// context generation exposed by this state before publishing a result.
final authProfileStateProvider = Provider<AuthProfileState>((ref) {
  final session = ref.watch(authControllerProvider).value;
  final access = session?.access;
  if (access is! AuthenticatedAccess || session == null) {
    return const AuthProfileState.inactive();
  }

  return AuthProfileState.unavailable(account: access.account, contextGeneration: session.profileContextGeneration);
});
