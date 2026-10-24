import 'package:material_ui/material_ui.dart';

/// Shared motion tokens, including system reduced-motion handling.
abstract final class AppMotion {
  static const fast = Duration(milliseconds: 160);
  static const standard = Duration(milliseconds: 240);
  static const page = Duration(milliseconds: 280);
  static const pageReverse = Duration(milliseconds: 200);
  static const panelEnter = standard;
  static const panelExit = Duration(milliseconds: 156);
  static const focusExit = Duration(milliseconds: 104);
  static const focusBorderEnter = Duration(milliseconds: 280);
  static const focusBorderExit = Duration(milliseconds: 200);
  static const inspectorDwell = Duration(milliseconds: 150);
  static const inspectorContent = page;
  static const shimmer = Duration(milliseconds: 1100);
  static const enterCurve = Curves.easeOutCubic;
  static const exitCurve = Curves.easeInCubic;

  static bool reducedOf(BuildContext context) =>
      MediaQuery.disableAnimationsOf(context) || MediaQuery.accessibleNavigationOf(context);

  static Duration durationOf(BuildContext context, Duration duration) => reducedOf(context) ? Duration.zero : duration;
}
