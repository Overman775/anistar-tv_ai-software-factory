import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';

/// Fullscreen golden window profiles shared by screen-level baselines.
///
/// A profile fixes the logical window and its 1:1 capture density. Adding a
/// new profile requires a layout that the existing profiles cannot
/// represent; callers cannot pass an arbitrary size or DPR instead.
enum GoldenProfile {
  /// TV layout reference window (ADR-0008).
  tv(Size(960, 540), AppDeviceProfile.tv),

  /// Handset portrait window.
  phonePortrait(Size(360, 800), AppDeviceProfile.mobile),

  /// Handset landscape window.
  phoneLandscape(Size(800, 360), AppDeviceProfile.mobile);

  const GoldenProfile(this.logicalSize, this.platform) : devicePixelRatio = 1;

  /// Logical window size; baselines capture 1:1 because the DPR is 1.
  final Size logicalSize;

  /// Device profile of the window; selects the matching pump harness.
  final AppDeviceProfile platform;

  /// Profiles never vary density; a new density needs its own profile.
  final double devicePixelRatio;
}

/// Text scale of a fullscreen baseline; the window itself stays owned by the profile.
enum GoldenTextScale {
  /// System default 100%.
  normal(1),

  /// Increased text 200% with unchanged window parameters.
  large(2);

  const GoldenTextScale(this.factor);

  /// Text multiplier applied through `TextScaler`.
  final double factor;
}

/// Baseline path for [scenario]: `goldens/<scenario>.<profile>[.largeText].png`.
String screenGoldenFile(String scenario, GoldenProfile profile, [GoldenTextScale textScale = GoldenTextScale.normal]) {
  final suffix = textScale == GoldenTextScale.large ? '.largeText' : '';
  return 'goldens/$scenario.${profile.name}$suffix.png';
}
