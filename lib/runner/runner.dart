import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app/app.dart';
import '../app/app_provider.dart';
import '../packages/core/services/preferences_service.dart';

/// Application entry point that initializes services and runs the app
Future<void> runApplication() async {
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Set preferred orientations for TV
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // Initialize services
  final sharedPreferences = await SharedPreferences.getInstance();
  final preferencesService = PreferencesService(sharedPreferences);

  // Run the app with providers
  runApp(
    MultiProvider(
      providers: [
        Provider<PreferencesService>.value(value: preferencesService),
      ],
      child: const AppProvider(child: App()),
    ),
  );
}
