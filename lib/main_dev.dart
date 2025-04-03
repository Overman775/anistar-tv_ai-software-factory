import 'package:anistar_tv/utils/logger/logger.dart';
import 'package:logger/logger.dart';

import 'runner/runner.dart';

/// Entry point for development version
void main() {
  // Set up logging for development
  Logger.level = Level.all; // Log everything
  logger = Logger(
    printer: PrettyPrinter(
      methodCount: 1, // number of method calls to be displayed
      errorMethodCount: 5, // number of method calls if stacktrace is provided
      lineLength: 120, // width of the output
      colors: true, // Colorful log messages
      printEmojis: true, // Print an emoji for each log message
      dateTimeFormat: DateTimeFormat.none, // Should each log print contain a timestamp
    ),
  );

  logger.d('Development initialized');

  // Set up any development-specific configurations here
  runApplication();
}
