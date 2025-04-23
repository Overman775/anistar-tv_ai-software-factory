import 'package:anistar_tv/packages/core/services/secure_storage.dart';
import 'package:anistar_tv/packages/core/services/shared_preferences_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/app.dart';
import '../app/app_provider.dart';

/// Application entry point that initializes services and runs the app
Future<void> runApplication() async {
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Set preferred orientations for TV
  await SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);

  // Initialize services
  final sharedPreferencesStorage = SharedPreferencesStorage();
  await sharedPreferencesStorage.init();

  final secureStorage = SecureStorage();

  // Run the app with providers
  runApp(AppProvider(sharedPreferences: sharedPreferencesStorage, secureStorage: secureStorage, child: App()));
}
