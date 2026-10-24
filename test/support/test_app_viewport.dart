import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';

/// A deterministic logical viewport shared by widget and golden harnesses.
final class TestAppViewport {
  const TestAppViewport({
    required this.profile,
    required this.logicalSize,
    this.devicePixelRatio = 1,
    this.textScale = 1,
    this.disableAnimations = false,
  });

  const TestAppViewport.tv({
    this.logicalSize = const Size(960, 540),
    this.devicePixelRatio = 1,
    this.textScale = 1,
    this.disableAnimations = false,
  }) : profile = AppDeviceProfile.tv;

  const TestAppViewport.mobile({
    this.logicalSize = const Size(390, 844),
    this.devicePixelRatio = 1,
    this.textScale = 1,
    this.disableAnimations = false,
  }) : profile = AppDeviceProfile.mobile;

  final AppDeviceProfile profile;
  final Size logicalSize;
  final double devicePixelRatio;
  final double textScale;
  final bool disableAnimations;
}

void setTestViewport(WidgetTester tester, TestAppViewport viewport) {
  final view = tester.view
    ..physicalSize = viewport.logicalSize * viewport.devicePixelRatio
    ..devicePixelRatio = viewport.devicePixelRatio;
  addTearDown(view.reset);
}
