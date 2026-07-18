import 'package:flutter/foundation.dart';

class AppConfig {
  static const flavor = String.fromEnvironment('FLAVOR', defaultValue: 'prod');
  static bool get isDevFlavor => flavor == 'dev' || !kReleaseMode;
}
