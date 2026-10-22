import 'package:material_ui/material_ui.dart';

import 'app_focus_style.dart';
import 'app_palette.dart';
import 'tv_typography.dart';

abstract final class AppTheme {
  static final ThemeData lightTheme = _createTheme(Brightness.light);
  static final ThemeData darkTheme = _createTheme(Brightness.dark);
  static final ThemeData mobileDarkTheme = _mobileTheme(darkTheme);
  static final ThemeData mobileLightTheme = _mobileTheme(lightTheme);

  static ThemeData _mobileTheme(ThemeData base) {
    final text = base.textTheme.copyWith(
      headlineLarge: base.textTheme.headlineLarge?.copyWith(fontSize: 28, height: 1.2),
      headlineMedium: base.textTheme.headlineMedium?.copyWith(fontSize: 24, height: 1.25),
      headlineSmall: base.textTheme.headlineSmall?.copyWith(fontSize: 22, height: 1.25),
      titleLarge: base.textTheme.titleLarge?.copyWith(fontSize: 20, height: 1.3),
      titleMedium: base.textTheme.titleMedium?.copyWith(fontSize: 16, height: 1.35),
      bodyLarge: base.textTheme.bodyLarge?.copyWith(fontSize: 16),
      bodyMedium: base.textTheme.bodyMedium?.copyWith(fontSize: 14),
      labelLarge: base.textTheme.labelLarge?.copyWith(fontSize: 14),
    );

    return base.copyWith(
      textTheme: text,
      appBarTheme: base.appBarTheme.copyWith(
        titleTextStyle: text.titleLarge?.copyWith(color: base.colorScheme.onSurface),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: base.iconButtonTheme.style?.copyWith(minimumSize: const WidgetStatePropertyAll(Size.square(48))),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: base.filledButtonTheme.style?.copyWith(
          minimumSize: const WidgetStatePropertyAll(Size(0, AppSizes.touchControl)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: base.textButtonTheme.style?.copyWith(
          minimumSize: const WidgetStatePropertyAll(Size(0, AppSizes.touchControl)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: base.outlinedButtonTheme.style?.copyWith(
          minimumSize: const WidgetStatePropertyAll(Size(0, AppSizes.touchControl)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppPalette.backgroundElevated,
        indicatorColor: AppPalette.menuControl,
        indicatorShape: const RoundedRectangleBorder(borderRadius: AppRadii.medium),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected) ? AppPalette.primary : AppPalette.textSecondary,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => text.labelMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: states.contains(WidgetState.selected) ? AppPalette.primary : AppPalette.textSecondary,
          ),
        ),
      ),
    );
  }

  static ThemeData _createTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final baseScheme =
        ColorScheme.fromSeed(
          seedColor: AppPalette.primary,
          brightness: brightness,
          primary: isDark ? AppPalette.primary : AppPalette.primarySoft,
          secondary: AppPalette.secondary,
          surface: isDark ? AppPalette.surface : AppPalette.textPrimary,
        ).copyWith(
          primary: AppPalette.primary,
          onPrimary: AppPalette.onPrimary,
          primaryContainer: AppPalette.accentSubtle,
          onPrimaryContainer: isDark ? AppPalette.textPrimary : AppPalette.background,
          secondary: AppPalette.primary,
          onSecondary: AppPalette.onPrimary,
          surface: isDark ? AppPalette.surface : AppPalette.textPrimary,
          surfaceDim: isDark ? AppPalette.background : AppPalette.textPrimary,
          surfaceBright: isDark ? AppPalette.surfaceElevated : Colors.white,
          surfaceContainerLowest: isDark ? AppPalette.background : Colors.white,
          surfaceContainerLow: isDark ? AppPalette.backgroundElevated : AppPalette.textPrimary,
          surfaceContainer: isDark ? AppPalette.surface : AppPalette.textPrimary,
          surfaceContainerHigh: isDark ? AppPalette.surfaceElevated : Colors.white,
          surfaceContainerHighest: isDark ? AppPalette.focusSurface : Colors.white,
          onSurface: isDark ? AppPalette.textPrimary : AppPalette.background,
          onSurfaceVariant: isDark ? AppPalette.textSecondary : AppPalette.focusSurface,
          outline: AppPalette.outline,
          outlineVariant: AppPalette.outline,
          error: AppPalette.danger,
          onError: AppPalette.onPrimary,
          scrim: AppPalette.scrim,
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
    final textTheme = TvTypography.apply(baseTextTheme)
        .apply(bodyColor: baseScheme.onSurface, displayColor: baseScheme.onSurface);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: baseScheme,
      scaffoldBackgroundColor: isDark ? AppPalette.background : AppPalette.textPrimary,
      focusColor: primaryColor.withValues(alpha: 0.2),
      splashColor: primaryHoverColor,
      textTheme: textTheme,
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: AppPalette.primary,
        selectionColor: AppPalette.primary.withValues(alpha: 0.3),
        selectionHandleColor: AppPalette.primary,
      ),
      textButtonTheme: TextButtonThemeData(style: AppFocusStyle.button()),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: AppFocusStyle.button().copyWith(
          side: const WidgetStatePropertyAll(BorderSide(color: AppPalette.outline)),
        ),
      ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: isDark ? AppPalette.textPrimary : AppPalette.background,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.titleLarge?.copyWith(color: isDark ? AppPalette.textPrimary : AppPalette.background),
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
        style:
            FilledButton.styleFrom(
              minimumSize: const Size(0, AppSizes.tvControl),
              foregroundColor: AppPalette.onPrimary,
              backgroundColor: AppPalette.primary,
              disabledBackgroundColor: AppPalette.surfaceElevated,
              disabledForegroundColor: AppPalette.textSecondary.withValues(alpha: 0.45),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
              shape: const RoundedRectangleBorder(borderRadius: AppRadii.medium),
              textStyle: textTheme.labelLarge,
            ).copyWith(
              side: filledButtonSide,
              backgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.disabled)) {
                  return AppPalette.surfaceElevated;
                }

                if (states.contains(WidgetState.pressed)) {
                  return AppPalette.primary.withValues(alpha: 0.82);
                }

                return AppFocusStyle.active(states) ? AppPalette.primarySoft : AppPalette.primary;
              }),
              overlayColor: isDark
                  ? WidgetStateProperty.resolveWith<Color?>((states) {
                      if (states.contains(WidgetState.pressed) || states.contains(WidgetState.focused)) {
                        return AppPalette.textPrimary.withValues(alpha: 0.1);
                      }

                      return states.contains(WidgetState.hovered)
                          ? AppPalette.textPrimary.withValues(alpha: 0.08)
                          : null;
                    })
                  : null,
            ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size.square(AppSizes.tvControl)),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) {
              return AppPalette.surfaceElevated;
            }
            if (AppFocusStyle.active(states)) {
              return AppPalette.focusSurface;
            }

            return isDark ? AppPalette.menuControl : Colors.white;
          }),
          foregroundColor: WidgetStatePropertyAll(isDark ? AppPalette.textPrimary : AppPalette.background),
          overlayColor: iconOverlayColor,
          side: iconSide,
          shape: const WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: AppRadii.medium)),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppPalette.backgroundElevated,
        modalBackgroundColor: AppPalette.backgroundElevated,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: AppRadii.large),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: AppPalette.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: AppRadii.large),
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
