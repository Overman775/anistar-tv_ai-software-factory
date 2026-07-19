import 'package:logger/logger.dart';

/// Adds the owning runtime type to a diagnostic message.
///
/// This mirrors the useful part of Mobile App's `ServicesLog<T>` while keeping
/// AniStar TV on its existing lightweight logger and local log viewer.
extension TypedLoggerExtension on Logger {
  void verboseFor<T extends Object>(String message) =>
      t('[${T.toString()}] $message');

  void debugFor<T extends Object>(String message) =>
      d('[${T.toString()}] $message');

  void infoFor<T extends Object>(String message) =>
      i('[${T.toString()}] $message');

  void warningFor<T extends Object>(String message) =>
      w('[${T.toString()}] $message');

  void errorFor<T extends Object>(
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) => e('[${T.toString()}] $message', error: error, stackTrace: stackTrace);
}
