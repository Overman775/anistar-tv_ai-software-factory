import 'package:anistar_tv/packages/core/services/secure_storage.dart';
import 'package:anistar_tv/packages/core/services/shared_preferences_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:logger/logger.dart';

import '../app/app.dart';
import '../app/app_provider.dart';

/// Application entry point that initializes services and runs the app
Future<void> runApplication({required Logger logger}) async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);

  final sharedPreferencesStorage = SharedPreferencesStorage();
  await sharedPreferencesStorage.init();

  final secureStorage = SecureStorage();

  runApp(
    AppProvider(
      logger: logger,
      sharedPreferences: sharedPreferencesStorage,
      secureStorage: secureStorage,
      child: App(logger: logger),
    ),
  );
}
