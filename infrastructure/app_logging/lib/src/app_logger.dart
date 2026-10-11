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
      // DevelopmentFilter suppresses everything when assertions are disabled,
      // including profile diagnostics and release errors.
      filter: ProductionFilter(),
      level: isDevelopment ? Level.all : Level.error,
      printer: PrettyPrinter(
        methodCount: isDevelopment ? 1 : 0,
        errorMethodCount: 5,
        lineLength: isDevelopment ? 120 : 100,
        colors: isDevelopment,
        printEmojis: isDevelopment,
        dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
      ),
      output: isDevelopment ? MultiOutput([ConsoleOutput(), FileLogOutput()]) : ConsoleOutput(),
    );
    _logger = logger;

    installErrorHandlers(logger);

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

  static void reportUnhandled(
    Object error,
    StackTrace? stackTrace, {
    String source = 'Uncaught app exception',
    Logger? logger,
  }) {
    (logger ?? AppLogger.logger).f('[UNHANDLED] $source', error: error, stackTrace: stackTrace);
  }

  /// Routes framework and platform failures through the application's logger.
  static void installErrorHandlers(Logger logger) {
    FlutterError.onError = (details) {
      reportUnhandled(details.exception, details.stack, source: 'FlutterError.onError', logger: logger);
    };
    PlatformDispatcher.instance.onError = (error, stackTrace) {
      reportUnhandled(error, stackTrace, source: 'PlatformDispatcher.onError', logger: logger);

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
