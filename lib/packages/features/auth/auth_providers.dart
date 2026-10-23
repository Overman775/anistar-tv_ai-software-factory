import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_controller.dart';
import 'auth_startup_stage.dart';
import 'domain/auth_access.dart';

export 'auth_controller.dart';
export 'auth_repository_provider.dart';
export 'auth_startup_stage.dart';
export 'domain/auth_access.dart';

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
