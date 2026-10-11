import 'dart:async';
import 'dart:io';

import 'package:app_logging/app_logging.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ui_kit/ui_kit.dart';

import 'offline_http_overrides.dart';

/// Initializes local assets and blocks accidental HTTP in unit/widget tests.
Future<void> runTestSuite(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  AppLogger.initForTest();
  final fontLoader = FontLoader(TvTypography.fontFamily)
    ..addFont(rootBundle.load('packages/ui_kit/assets/fonts/Inter-Regular.otf'))
    ..addFont(rootBundle.load('packages/ui_kit/assets/fonts/Inter-Medium.otf'))
    ..addFont(rootBundle.load('packages/ui_kit/assets/fonts/Inter-Bold.otf'));
  await fontLoader.load();
  final icons = FontLoader('MaterialIcons')..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
  await icons.load();
  // Test registration and execution use different zones. Install this globally
  // in the test isolate so it also guards the actual test bodies.
  HttpOverrides.global = OfflineHttpOverrides();
  await testMain();
}
