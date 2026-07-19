import 'package:flutter/foundation.dart';

class AppConfig {
  static const flavor = String.fromEnvironment('FLAVOR', defaultValue: 'prod');

  /// Enables tools that could expose diagnostics or local application data.
  ///
  /// This deliberately depends on the build mode rather than the selected API
  /// flavor: a production-flavor debug build remains diagnosable, while every
  /// release build stays free of developer UI.
  static bool get isDebugToolsEnabled => !kReleaseMode;
}
