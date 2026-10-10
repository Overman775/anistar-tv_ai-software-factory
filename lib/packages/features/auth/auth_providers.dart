import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_controller.dart';

export 'auth_controller.dart';
export 'auth_repository_provider.dart';

final authControllerProvider = AsyncNotifierProvider<AuthController, String?>(AuthController.new);
