import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app/app.dart';
import '../app/app_provider.dart';

/// Application entry point that initializes services and runs the app
Future<void> runApplication() async {
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Set preferred orientations for TV
  await SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);

  // Initialize services
  final sharedPreferences = await SharedPreferences.getInstance();

  // Run the app with providers
  runApp(AppProvider(sharedPreferences: sharedPreferences, child: App()));
}
