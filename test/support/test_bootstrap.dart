import 'dart:async';
import 'dart:io';

import 'package:app_logging/app_logging.dart';
import 'package:flutter/services.dart';
// Decode the UI kit's bundled SVG assets before widget-test fake clocks start.
// ignore: depend_on_referenced_packages
import 'package:flutter_svg/flutter_svg.dart';
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
  for (final symbol in AppIconType.values) {
    await SvgAssetLoader('assets/icons/${symbol.assetName}.svg', packageName: Assets.package).loadBytes(null);
  }
  // Test registration and execution use different zones. Install this globally
  // in the test isolate so it also guards the actual test bodies.
  HttpOverrides.global = OfflineHttpOverrides();
  await testMain();
}
