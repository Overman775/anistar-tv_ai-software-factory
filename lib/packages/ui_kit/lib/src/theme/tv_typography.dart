import 'package:flutter/material.dart';

/// Typography scale optimised for legibility at TV viewing distance.
abstract final class TvTypography {
  static const fontFamily = 'Inter';

  static TextTheme apply(TextTheme base) => base.copyWith(
    displaySmall: base.displaySmall?.copyWith(fontFamily: fontFamily, fontWeight: FontWeight.w700, letterSpacing: -1),
    headlineLarge: base.headlineLarge?.copyWith(
      fontFamily: fontFamily,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.6,
    ),
    headlineMedium: base.headlineMedium?.copyWith(
      fontFamily: fontFamily,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.4,
    ),
    headlineSmall: base.headlineSmall?.copyWith(fontFamily: fontFamily, fontWeight: FontWeight.w700),
    titleLarge: base.titleLarge?.copyWith(fontFamily: fontFamily, fontSize: 24, fontWeight: FontWeight.w700),
    titleMedium: base.titleMedium?.copyWith(fontFamily: fontFamily, fontSize: 19, fontWeight: FontWeight.w500),
    bodyLarge: base.bodyLarge?.copyWith(fontFamily: fontFamily, fontSize: 18, height: 1.45),
    bodyMedium: base.bodyMedium?.copyWith(fontFamily: fontFamily, fontSize: 16, height: 1.4),
    labelLarge: base.labelLarge?.copyWith(
      fontFamily: fontFamily,
      fontSize: 16,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.2,
    ),
  );
}
