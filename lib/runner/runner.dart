import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';

import '../app/app.dart';
import '../app/app_providers.dart';
import '../packages/core/core.dart';

/// Application entry point that initializes services and runs the app
Future<void> runApplication({required Logger logger, required bool allowLocalApiFallback}) async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);

  final sharedPreferencesStorage = SharedPreferencesStorage();
  await sharedPreferencesStorage.init();

  final secureStorage = SecureStorage();
  final apiBaseUri = AnistarApiConfig.baseUri(allowLocalFallback: allowLocalApiFallback);

  runApp(
    ProviderScope(
      overrides: [
        loggerProvider.overrideWithValue(logger),
        networkConfigProvider.overrideWithValue(NetworkConfig(baseUri: apiBaseUri)),
        sharedPreferencesStorageProvider.overrideWithValue(sharedPreferencesStorage),
        secureStorageProvider.overrideWithValue(secureStorage),
      ],
      child: const App(),
    ),
  );
}
