import 'package:material_ui/material_ui.dart';

import 'app_device_profile.dart';

/// Device role is independent of window size: a rotated phone stays mobile.
class AppLayoutScope extends InheritedWidget {
  const AppLayoutScope({
    required this.profile,
    required super.child,
    this.viewportSize = Size.zero,
    this.horizontalPadding = 16,
    super.key,
  });

  static double horizontalPaddingOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppLayoutScope>()?.horizontalPadding ?? 16;

  static bool isTvOf(BuildContext context) => profileOf(context) == AppDeviceProfile.tv;

  static AppDeviceProfile profileOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppLayoutScope>()?.profile ?? AppDeviceProfile.tv;

  final AppDeviceProfile profile;
  final Size viewportSize;
  final double horizontalPadding;

  @override
  bool updateShouldNotify(AppLayoutScope oldWidget) =>
      profile != oldWidget.profile ||
      viewportSize != oldWidget.viewportSize ||
      horizontalPadding != oldWidget.horizontalPadding;
}
