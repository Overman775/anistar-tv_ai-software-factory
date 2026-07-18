import 'package:flutter/material.dart';

abstract final class AppPalette {
  static const background = Color(0xFF080B14);
  static const backgroundElevated = Color(0xFF0D1220);
  static const surface = Color(0xFF141B2D);
  static const surfaceElevated = Color(0xFF1B2440);
  static const primary = Color(0xFFA855F7);
  static const primarySoft = Color(0xFF7C3AED);
  static const secondary = Color(0xFF22D3EE);
  static const success = Color(0xFF34D399);
  static const warning = Color(0xFFFBBF24);
  static const textPrimary = Color(0xFFF8FAFC);
  static const textSecondary = Color(0xFFAAB6CC);
  static const outline = Color(0xFF2B3857);
}

abstract final class AppSpacing {
  static const double xs = 6;
  static const double sm = 10;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
}

abstract final class AppRadii {
  static const small = BorderRadius.all(Radius.circular(10));
  static const medium = BorderRadius.all(Radius.circular(16));
  static const large = BorderRadius.all(Radius.circular(22));
  static const pill = BorderRadius.all(Radius.circular(999));
}

abstract final class AppMotion {
  static const fast = Duration(milliseconds: 160);
  static const standard = Duration(milliseconds: 240);
}
