import 'package:material_ui/material_ui.dart';

import '../theme/app_palette.dart';
import 'app_layout_scope.dart';
import 'tv_focusable.dart';

/// A busy action retains its focus target while rejecting every repeat activation.
class AppButton extends StatelessWidget {
  const AppButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.variant = AppButtonVariant.primary,
    this.enabled = true,
    this.busy = false,
    this.autofocus = false,
    this.focusNode,
    this.onFocusChanged,
    super.key,
  });

  final String label;
  final VoidCallback onPressed;
  final Widget? icon;
  final AppButtonVariant variant;
  final bool enabled;
  final bool busy;
  final bool autofocus;
  final FocusNode? focusNode;
  final ValueChanged<bool>? onFocusChanged;

  @override
  Widget build(BuildContext context) => TvFocusable(
    onPressed: onPressed,
    enabled: enabled,
    busy: busy,
    autofocus: autofocus,
    focusNode: focusNode,
    onFocusChanged: onFocusChanged,
    semanticLabel: label,
    stateBuilder: (context, state) {
      final focused = state.focused;
      final primary = variant == AppButtonVariant.primary;
      final foreground = switch (variant) {
        AppButtonVariant.primary => AppPalette.onPrimary,
        AppButtonVariant.neutral => AppPalette.textPrimary,
        AppButtonVariant.danger => AppPalette.danger,
      };
      final background = switch ((primary, state.pressed, state.focused || state.hovered)) {
        (true, true, _) => AppPalette.primary.withValues(alpha: 0.82),
        (true, _, true) => AppPalette.primarySoft,
        (true, _, _) => AppPalette.primary,
        (_, true, _) => AppPalette.surfaceElevated,
        (_, _, true) => AppPalette.focusSurface,
        _ => AppPalette.surface,
      };
      final focusBorderColor = primary ? AppPalette.onPrimary : AppPalette.primary;

      return AnimatedContainer(
        duration: AppMotion.durationOf(context, focused ? AppMotion.fast : AppMotion.focusExit),
        curve: focused ? AppMotion.enterCurve : AppMotion.exitCurve,
        constraints: BoxConstraints(
          minWidth: AppSizes.touchControl,
          minHeight: AppLayoutScope.isTvOf(context) ? AppSizes.tvControl : AppSizes.touchControl,
        ),
        decoration: BoxDecoration(
          color: background,
          borderRadius: AppRadii.medium,
          border: Border.all(color: focused ? focusBorderColor : AppPalette.outline, width: 2),
        ),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
        child: Opacity(
          opacity: enabled ? 1 : 0.45,
          child: IconTheme(
            data: IconThemeData(color: foreground, size: 24),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (busy) ...[
                  SizedBox.square(dimension: 20, child: CircularProgressIndicator(color: foreground, strokeWidth: 2)),
                  const SizedBox(width: AppSpacing.sm),
                ] else if (icon case final icon?) ...[
                  ExcludeSemantics(child: icon),
                  const SizedBox(width: AppSpacing.sm),
                ],
                Flexible(
                  child: ExcludeSemantics(
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.labelLarge
                          ?.copyWith(color: foreground, fontWeight: primary ? FontWeight.w800 : FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

enum AppButtonVariant { primary, neutral, danger }
