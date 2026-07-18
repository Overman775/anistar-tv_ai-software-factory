import 'package:anistar_tv/utils/logger/file_log_output.dart';
import 'package:logger/logger.dart';

import 'runner/runner.dart';

/// Runs the development application with verbose file logging.
Future<void> main() async {
  final appLogger = Logger(
    printer: PrettyPrinter(
      methodCount: 1,
      errorMethodCount: 5,
      lineLength: 120,
      colors: true,
      printEmojis: true,
      dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
    ),
    output: FileLogOutput(),
  );
  Logger.level = Level.all;

  await runApplication(logger: appLogger);
}
