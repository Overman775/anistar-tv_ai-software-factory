import 'package:material_ui/material_ui.dart';

import 'app_palette.dart';

/// Shared focus and hover treatment for TV menus, choices and filters.
abstract final class AppFocusStyle {
  static bool active(Set<WidgetState> states) =>
      !states.contains(WidgetState.disabled) &&
      (states.contains(WidgetState.focused) || states.contains(WidgetState.hovered));

  static BoxDecoration decoration({
    required bool focused,
    bool selected = false,
    Color restingColor = Colors.transparent,
    BorderRadius radius = AppRadii.medium,
  }) => BoxDecoration(
    color: switch ((focused, selected)) {
      (true, _) => AppPalette.focusSurface,
      (_, true) => AppPalette.surfaceElevated,
      _ => restingColor,
    },
    gradient: focused ? const LinearGradient(colors: [AppPalette.focusSurface, AppPalette.focusSurfaceEnd]) : null,
    borderRadius: radius,
    border: Border.all(color: focused ? AppPalette.focusOutline : Colors.transparent, width: 2),
    boxShadow: focused ? const [BoxShadow(color: AppPalette.focusGlow, blurRadius: 18, spreadRadius: 1)] : const [],
  );

  static ButtonStyle button({bool selected = false, BorderRadius radius = AppRadii.pill}) =>
      TextButton.styleFrom(
        minimumSize: const Size(56, 56),
        foregroundColor: AppPalette.textPrimary,
        disabledForegroundColor: AppPalette.textSecondary,
        backgroundColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: radius),
      ).copyWith(
        side: const WidgetStatePropertyAll(BorderSide.none),
        overlayColor: const WidgetStatePropertyAll(Color(0x167C3AED)),
        backgroundBuilder: (context, states, child) => DecoratedBox(
          decoration: decoration(focused: active(states), selected: selected, radius: radius),
          child: child,
        ),
      );
}
