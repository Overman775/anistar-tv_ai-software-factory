import 'dart:async';

import 'package:app_logger/app_logger.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/app.dart';
import '../app/app_providers.dart';
import '../packages/core/core.dart';

/// Application entry point that initializes services and runs the app.
Future<void> runApplication({required bool allowLocalApiFallback}) async {
  await runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    final logger = AppLogger.init(isDevelopment: !const bool.fromEnvironment('dart.vm.product'));
    Bloc.observer = AppBlocObserver(logger);

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
  }, AppLogger.reportUnhandled);
}
