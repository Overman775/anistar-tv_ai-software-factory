import 'package:anistar_tv/utils/logger/file_log_output.dart';
import 'package:anistar_tv/utils/logger/logger.dart';
import 'package:flutter/material.dart'; // Required for WidgetsFlutterBinding
import 'package:logger/logger.dart'; // Keep for existing logger setup if still used alongside LogService

import 'runner/runner.dart';

/// Entry point for development version
Future<void> main() async {
  // Make main async
  WidgetsFlutterBinding.ensureInitialized(); // Ensure bindings are initialized

  // Initialize LogService
  // Note: The old logger setup might be redundant if appLogger from LogService is used everywhere.
  // For now, LogService.initialize will set up its own Logger instance.

  // The global `appLogger` from LogService is now available.
  // The old `logger` instance might still be used in some places, or can be phased out.
  // If the old logger setup is to be completely replaced, this part can be removed:
  logger = Logger(
    // This logger is now potentially separate from appLogger's internal logger
    printer: PrettyPrinter(
      methodCount: 1,
      errorMethodCount: 5,
      lineLength: 120,
      colors: true,
      printEmojis: true,
      // dateTimeFormat: DateTimeFormat.none, // PrettyPrinter does not have dateTimeFormat directly
      // It uses `printTime` boolean.
      printTime: true,
      // Example: enable time printing for this instance
    ),
    output: FileLogOutput(),
  );
  Logger.level = Level.all; // This sets level for the 'logger' package's default logger,
  // ensure LogService's logger is also configured if needed.

  // Set up any development-specific configurations here
  runApplication();
}
