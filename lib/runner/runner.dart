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
    logger.infoFor<Runner>('Starting application');

    await SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);

    final sharedPreferencesStorage = SharedPreferencesStorage(logger: logger);
    await sharedPreferencesStorage.init();

    final secureStorage = SecureStorage(logger: logger);
    final apiBaseUri = AnistarApiConfig.baseUri(allowLocalFallback: allowLocalApiFallback);
    logger.infoFor<Runner>('Runtime dependencies ready; API host: ${apiBaseUri.host}');

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
    logger.infoFor<Runner>('Application mounted');
  }, AppLogger.reportUnhandled);
}

final class Runner {}
