import 'package:material_ui/material_ui.dart';

import 'app_palette.dart';
import 'tv_typography.dart';

abstract final class AppTheme {
  static final ThemeData lightTheme = _createTheme(Brightness.light);
  static final ThemeData darkTheme = _createTheme(Brightness.dark);

  static ThemeData _createTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final baseScheme = ColorScheme.fromSeed(
      seedColor: AppPalette.primary,
      brightness: brightness,
      primary: isDark ? AppPalette.primary : AppPalette.primarySoft,
      secondary: AppPalette.secondary,
      surface: isDark ? AppPalette.surface : const Color(0xFFF7F5FC),
    );
    final baseTextTheme = ThemeData(brightness: brightness).textTheme;
    final primaryColor = baseScheme.primary;
    final primaryHoverColor = primaryColor.withValues(alpha: 0.12);
    final iconOverlayColor = WidgetStateProperty.resolveWith<Color?>((states) {
      final focused = states.contains(WidgetState.focused);

      return focused ? primaryColor.withValues(alpha: 0.3) : primaryHoverColor;
    });
    final iconSide = WidgetStateProperty.resolveWith<BorderSide?>((states) {
      final focused = states.contains(WidgetState.focused);

      return BorderSide(color: focused ? primaryColor : Colors.transparent, width: focused ? 3 : 0);
    });
    final filledButtonSide = WidgetStateProperty.resolveWith<BorderSide?>((states) {
      final focused = states.contains(WidgetState.focused);

      return BorderSide(color: focused ? baseScheme.onPrimary : Colors.transparent, width: focused ? 3 : 0);
    });
    final textTheme = TvTypography.apply(baseTextTheme);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: baseScheme,
      scaffoldBackgroundColor: isDark ? AppPalette.background : const Color(0xFFF7F5FC),
      focusColor: primaryColor.withValues(alpha: 0.2),
      splashColor: primaryHoverColor,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: isDark ? AppPalette.textPrimary : const Color(0xFF171124),
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: isDark ? AppPalette.textPrimary : const Color(0xFF171124),
        ),
      ),
      cardTheme: CardThemeData(
        margin: EdgeInsets.zero,
        color: isDark ? AppPalette.surface : Colors.white,
        elevation: 0,
        clipBehavior: Clip.antiAlias,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.large),
      ),
      dividerTheme: DividerThemeData(color: baseScheme.outlineVariant.withValues(alpha: 0.5), thickness: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? AppPalette.surfaceElevated.withValues(alpha: 0.82) : Colors.white,
        contentPadding: const EdgeInsets.all(AppSpacing.md),
        border: const OutlineInputBorder(borderRadius: AppRadii.medium, borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadii.medium,
          borderSide: BorderSide(color: baseScheme.outlineVariant.withValues(alpha: 0.7)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadii.medium,
          borderSide: BorderSide(color: primaryColor, width: 2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 56),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
          shape: const RoundedRectangleBorder(borderRadius: AppRadii.medium),
          textStyle: textTheme.labelLarge,
        ).copyWith(side: filledButtonSide),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size.square(56)),
          backgroundColor: WidgetStatePropertyAll(isDark ? AppPalette.surface.withValues(alpha: 0.75) : Colors.white),
          foregroundColor: WidgetStatePropertyAll(isDark ? AppPalette.textPrimary : const Color(0xFF171124)),
          overlayColor: iconOverlayColor,
          side: iconSide,
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: primaryColor,
        linearTrackColor: primaryColor.withValues(alpha: 0.16),
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStatePropertyAll(primaryColor.withValues(alpha: 0.68)),
        radius: const Radius.circular(99),
        thickness: const WidgetStatePropertyAll(6),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: const BoxDecoration(color: AppPalette.surfaceElevated, borderRadius: AppRadii.small),
        textStyle: textTheme.bodyMedium?.copyWith(color: AppPalette.textPrimary),
      ),
    );
  }
}
