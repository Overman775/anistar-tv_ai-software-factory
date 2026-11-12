import 'package:material_ui/material_ui.dart';

import '../theme/app_palette.dart';
import 'app_focus_border.dart';
import 'app_icon.dart';
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
    this.minHeight,
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

  /// Overrides the visual minimum for a specific layout role. Text may grow.
  final double? minHeight;

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
      final metadata = variant == AppButtonVariant.metadata;
      final radius = metadata ? AppRadii.small : AppRadii.medium;
      final primary = variant == AppButtonVariant.primary;
      final foreground = switch (variant) {
        AppButtonVariant.primary => AppPalette.onPrimary,
        AppButtonVariant.neutral || AppButtonVariant.metadata => AppPalette.textPrimary,
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

      final button = AppFocusBorder(
        focused: focused,
        radius: radius,
        restingColor: AppPalette.outline,
        child: AnimatedContainer(
          duration: AppMotion.durationOf(context, focused ? AppMotion.focusBorderEnter : AppMotion.focusBorderExit),
          curve: focused ? AppMotion.enterCurve : AppMotion.exitCurve,
          constraints: BoxConstraints(
            minWidth: metadata ? 0 : AppSizes.touchControl,
            minHeight:
                minHeight ??
                switch ((metadata, AppLayoutScope.isTvOf(context))) {
                  (true, _) => AppSizes.metadataControl,
                  (_, true) => AppSizes.tvControl,
                  _ => AppSizes.touchControl,
                },
          ),
          decoration: BoxDecoration(color: background, borderRadius: radius),
          padding: metadata
              ? const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs)
              : const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
          child: Opacity(
            opacity: enabled ? 1 : 0.45,
            child: IconTheme(
              data: IconThemeData(color: foreground, size: metadata ? 16 : 20),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (busy) ...[
                    SizedBox.square(
                      dimension: 20,
                      child: AppMotion.reducedOf(context)
                          ? const AppIcon(AppIconType.loaderCircle)
                          : CircularProgressIndicator(color: foreground, strokeWidth: 2),
                    ),
                    SizedBox(width: metadata ? AppSpacing.xs : AppSpacing.sm),
                  ] else if (icon case final icon?) ...[
                    ExcludeSemantics(child: icon),
                    SizedBox(width: metadata ? AppSpacing.xs : AppSpacing.sm),
                  ],
                  Flexible(
                    child: ExcludeSemantics(
                      child: Text(
                        label,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: foreground,
                          fontSize: 16,
                          fontWeight: primary ? FontWeight.w800 : FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      if (!metadata) return button;

      return ConstrainedBox(
        constraints: const BoxConstraints(minWidth: AppSizes.touchControl, minHeight: AppSizes.touchControl),
        child: Center(widthFactor: 1, heightFactor: 1, child: button),
      );
    },
  );
}

enum AppButtonVariant { primary, neutral, danger, metadata }
