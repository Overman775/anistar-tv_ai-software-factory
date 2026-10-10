import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

import 'file_log_output.dart';

/// Creates consistently configured application loggers for every runtime mode.
abstract final class AppLogger {
  static Logger? _logger;

  static Logger get logger => _logger ??= init(isDevelopment: kDebugMode || kProfileMode);

  static Logger init({required bool isDevelopment}) {
    Logger.level = isDevelopment ? Level.all : Level.error;
    final logger = Logger(
      printer: PrettyPrinter(
        methodCount: isDevelopment ? 1 : 0,
        errorMethodCount: 5,
        lineLength: isDevelopment ? 120 : 100,
        colors: isDevelopment,
        printEmojis: isDevelopment,
        dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
      ),
      output: isDevelopment ? FileLogOutput() : ConsoleOutput(),
    );
    _logger = logger;

    _installFrameworkErrorHandlers(logger);

    return logger;
  }

  /// Silences package logging in unit and widget tests without touching I/O.
  @visibleForTesting
  static Logger initForTest() {
    Logger.level = Level.off;
    final logger = Logger(level: Level.off, output: _DiscardLogOutput());
    _logger = logger;

    return logger;
  }

  static void reportUnhandled(Object error, StackTrace stackTrace) {
    logger.e('Unhandled application exception', error: error, stackTrace: stackTrace);
  }

  static void _installFrameworkErrorHandlers(Logger logger) {
    FlutterError.onError = (details) {
      logger.e('Flutter framework error', error: details.exception, stackTrace: details.stack);
    };
    PlatformDispatcher.instance.onError = (error, stackTrace) {
      logger.e('Platform dispatcher error', error: error, stackTrace: stackTrace);

      return true;
    };
  }
}

final class _DiscardLogOutput extends LogOutput {
  @override
  void output(OutputEvent event) {
    if (event.lines.isEmpty) {
      return;
    }
  }
}
