import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

import 'runner/runner.dart';

/// Entry point for production version
Future<void> main() async {
  Logger.level = Level.warning;
  final appLogger = Logger(
    printer: PrettyPrinter(
      methodCount: 0,
      errorMethodCount: 5,
      lineLength: 100,
      colors: false,
      printEmojis: false,
      dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
    ),
  );

  if (kReleaseMode) {
    // ignore: no-empty-block
    debugPrint = (String? message, {int? wrapWidth}) {};
    appLogger.i('Standard debugPrint disabled for release mode.');
  } else {
    appLogger.w('Running in Debug/Profile mode with the production entry point.');
  }

  appLogger.i('Production initialized');

  await runApplication(logger: appLogger);
}
