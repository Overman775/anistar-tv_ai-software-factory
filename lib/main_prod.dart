import 'package:flutter/foundation.dart';

import 'runner/runner.dart';

/// Entry point for production version
void main() {
  // Disable debug prints in production
  if (kReleaseMode) {
    debugPrint = (String? message, {int? wrapWidth}) {};
  }

  // Run the application
  runApplication();
}
