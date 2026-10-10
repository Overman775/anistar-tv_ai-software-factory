import 'package:app_logging/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'secure_storage.dart';
import 'shared_preferences_storage.dart';

final sharedPreferencesStorageProvider = Provider<SharedPreferencesStorage>(
  (ref) => SharedPreferencesStorage(logger: ref.watch(loggerProvider)),
);

final secureStorageProvider = Provider<SecureStorage>((ref) => SecureStorage(logger: ref.watch(loggerProvider)));
