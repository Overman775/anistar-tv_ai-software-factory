import 'package:material_ui/material_ui.dart';

export 'app_motion.dart';
export 'app_spacing.dart';

/// Semantic colours shared by TV and touch surfaces.
abstract final class AppPalette {
  static const background = Color(0xFF101214);
  static const backgroundElevated = Color(0xFF171A1C);
  static const surface = Color(0xFF1B1E21);
  static const surfaceElevated = Color(0xFF2B3034);
  static const catalogHorizon = Color(0xFF1C2024);
  static const menuControl = Color(0xFF242A2D);
  static const focusSurface = Color(0xFF30373A);
  static const focusSurfaceEnd = focusSurface;
  static const focusOutline = primary;
  static const focusGlow = Color(0x33D986A6);
  static const primary = Color(0xFFD986A6);
  static const primarySoft = Color(0xFFE6A2BC);
  static const onPrimary = Color(0xFF24141C);
  static const accentSubtle = Color(0x10D986A6);
  static const secondary = primary;
  static const success = Color(0xFFA9D4BC);
  static const warning = Color(0xFFE2CB9A);
  static const danger = Color(0xFFFFB7B0);
  static const textPrimary = Color(0xFFF5F6F3);
  static const textSecondary = Color(0xFFB2B9BD);
  static const outline = Color(0xFF394045);
  static const media = Color(0xFF080C0D);
  static const mediaCaptionShade = Color(0xE6080C0D);
  static const badge = Color(0xEE101214);
  static const inspector = Color(0xE6101214);
  static const favoriteRibbon = Color(0xA3101214);
  static const shadowStrong = Color(0x88000000);
  static const shadowSoft = Color(0x55000000);
  static const scrim = Color(0x99000000);
  static const scrimHeavy = Color(0xAA000000);
  static const playerBackground = Color(0xFF050606);
  static const playerSurface = Color(0xFF191D20);
  static const playerText = Color(0xFFF1F3F4);
  static const playerMuted = Color(0xFFB7BABD);
  static const playerOnLight = Color(0xFF121517);
  static const playerShadeTop = Color(0xC2000000);
  static const playerShadeBottom = Color(0xE0000000);
}
