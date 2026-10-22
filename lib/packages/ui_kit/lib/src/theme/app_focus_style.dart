import 'package:material_ui/material_ui.dart';

import 'app_palette.dart';

/// Shared focus and hover treatment for menus, choices and controls.
abstract final class AppFocusStyle {
  static bool active(Set<WidgetState> states) =>
      !states.contains(WidgetState.disabled) &&
      (states.contains(WidgetState.focused) || states.contains(WidgetState.hovered));

  static BoxDecoration decoration({
    required bool focused,
    bool selected = false,
    bool pressed = false,
    Color restingColor = Colors.transparent,
    BorderRadius radius = AppRadii.medium,
  }) => BoxDecoration(
    color: pressed
        ? AppPalette.surfaceElevated
        : switch ((focused, selected)) {
            (true, _) => AppPalette.focusSurface,
            (_, true) => AppPalette.accentSubtle,
            _ => restingColor,
          },
    borderRadius: radius,
    border: Border.all(color: focused ? AppPalette.focusOutline : Colors.transparent, width: 2),
    boxShadow: focused ? const [BoxShadow(color: AppPalette.focusGlow, blurRadius: 12)] : const [],
  );

  static ButtonStyle button({bool selected = false, BorderRadius radius = AppRadii.medium}) =>
      TextButton.styleFrom(
        minimumSize: const Size(AppSizes.tvControl, AppSizes.tvControl),
        foregroundColor: selected ? AppPalette.primary : AppPalette.textPrimary,
        disabledForegroundColor: AppPalette.textSecondary.withValues(alpha: 0.45),
        backgroundColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: radius),
      ).copyWith(
        side: const WidgetStatePropertyAll(BorderSide.none),
        overlayColor: const WidgetStatePropertyAll(AppPalette.accentSubtle),
        backgroundBuilder: (context, states, child) => DecoratedBox(
          decoration: decoration(
            focused: active(states),
            selected: selected,
            pressed: states.contains(WidgetState.pressed),
            radius: radius,
          ),
          child: child,
        ),
      );
}
