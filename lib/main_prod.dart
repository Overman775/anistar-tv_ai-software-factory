import 'package:anistar_tv/utils/logger/logger.dart';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

import 'runner/runner.dart';

/// Entry point for production version
void main() {
  // Set up logging for production
  Logger.level = Level.warning; // Only log warnings and errors
  logger = Logger(
    printer: PrettyPrinter(
      methodCount: 0, // Don't show method calls
      errorMethodCount: 5,
      lineLength: 100,
      colors: false,
      printEmojis: false,
      dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart, // Include timestamp for production logs
    ),
  );

  // Disable standard debug prints in production
  if (kReleaseMode) {
    debugPrint = (String? message, {int? wrapWidth}) {};
    logger.i('Standard debugPrint disabled for release mode.');
  } else {
    logger.w('Running in Debug/Profile mode, but using production entry point!');
  }

  logger.i('Production initialized');

  // Run the application
  runApplication();
}
