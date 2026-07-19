import 'dart:async';

import 'package:app_logger/app_logger.dart';

/// Prevents test output from being polluted by application diagnostics.
///
/// Individual tests can still inject a capturing [Logger] when they need to
/// verify a logging interaction.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  AppLogger.initForTest();
  await testMain();
}
