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
    ..addFont(rootBundle.load(Assets.fonts.manrope400))
    ..addFont(rootBundle.load(Assets.fonts.manrope500))
    ..addFont(rootBundle.load(Assets.fonts.manrope600))
    ..addFont(rootBundle.load(Assets.fonts.manrope700))
    ..addFont(rootBundle.load(Assets.fonts.manrope800));
  await fontLoader.load();
  final icons = FontLoader('MaterialIcons')..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
  await icons.load();
  final lucide = FontLoader('packages/lucide_icons_flutter/Lucide')
    ..addFont(rootBundle.load('packages/lucide_icons_flutter/assets/lucide.ttf'));
  await lucide.load();
  // Test registration and execution use different zones. Install this globally
  // in the test isolate so it also guards the actual test bodies.
  HttpOverrides.global = OfflineHttpOverrides();
  await testMain();
}
