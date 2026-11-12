import 'package:material_ui/material_ui.dart';

/// Shared motion tokens, including system reduced-motion handling.
abstract final class AppMotion {
  static const fast = Duration(milliseconds: 160);
  static const standard = Duration(milliseconds: 240);
  static const page = Duration(milliseconds: 280);
  static const pageReverse = Duration(milliseconds: 200);
  static const panelEnter = standard;
  static const panelExit = Duration(milliseconds: 156);
  static const focusBorderEnter = page;
  static const focusBorderExit = Duration(milliseconds: 180);
  static const focusExit = focusBorderExit;
  static const inspectorDwell = Duration(milliseconds: 150);
  static const inspectorContent = page;
  static const shimmer = Duration(milliseconds: 1100);
  static const enterCurve = Cubic(0.215, 0.61, 0.355, 1);
  static const exitCurve = Cubic(0.55, 0.055, 0.675, 0.19);

  static bool reducedOf(BuildContext context) =>
      MediaQuery.disableAnimationsOf(context) || MediaQuery.accessibleNavigationOf(context);

  static Duration durationOf(BuildContext context, Duration duration) => reducedOf(context) ? Duration.zero : duration;
}
