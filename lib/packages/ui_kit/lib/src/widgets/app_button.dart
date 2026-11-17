import 'package:material_ui/material_ui.dart';
import 'package:sizer/sizer.dart';

import '../theme/app_palette.dart';
import '../theme/app_typography.dart';
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
    this.restingColor,
    this.adaptiveTv = false,
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

  final Color? restingColor;

  final bool adaptiveTv;

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
      final tv = AppLayoutScope.isTvOf(context);
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
        _ => restingColor ?? AppPalette.surface,
      };
      final double extent;
      final double glyph;
      final double gap;
      final double minWidth;
      final EdgeInsets padding;
      final adaptive = tv && adaptiveTv;
      final defaultExtent = tv ? AppSizes.tvControl : AppSizes.touchControl;
      final tvExtent = adaptive ? AppSizes.adaptiveTvControl : defaultExtent;
      final baseLabelStyle = Theme.of(context).textTheme.labelLarge?.copyWith(fontSize: 16);
      if (metadata) {
        extent = adaptive ? AppSizes.adaptiveTvMetadataControl : AppSizes.metadataControl;
        glyph = adaptive ? 2.23.vmin.clamp(14.0, 16.0) : 16.0;
        gap = adaptive ? 0.56.h.clamp(4.0, 6.0) : AppSpacing.xs;
        minWidth = 0;
        padding = adaptive
            ? EdgeInsets.symmetric(horizontal: 0.63.w.clamp(6.0, 8.0), vertical: 0.56.h.clamp(4.0, 6.0))
            : const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs);
      } else {
        extent = minHeight ?? tvExtent;
        glyph = adaptive ? 2.78.vmin.clamp(18.0, 20.0) : 20.0;
        gap = adaptive ? AppSpacing.adaptiveTvControlGap : AppSpacing.sm;
        minWidth = tvExtent;
        padding = adaptive
            ? EdgeInsets.symmetric(horizontal: 1.25.w.clamp(12.0, 16.0), vertical: 1.12.h.clamp(6.0, 8.0))
            : const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm);
      }
      var roleStyle = baseLabelStyle;
      if (adaptive) {
        roleStyle = metadata ? AppTypography.metadataControlTextOf(context) : AppTypography.actionTextOf(context);
      }
      final labelStyle = roleStyle?.copyWith(
        color: foreground,
        fontWeight: primary ? FontWeight.w800 : FontWeight.w600,
      );

      final button = AppFocusBorder(
        focused: focused,
        radius: radius,
        restingColor: AppPalette.outline,
        child: AnimatedContainer(
          duration: AppMotion.durationOf(context, focused ? AppMotion.focusBorderEnter : AppMotion.focusBorderExit),
          curve: focused ? AppMotion.enterCurve : AppMotion.exitCurve,
          constraints: BoxConstraints(minWidth: minWidth, minHeight: extent),
          decoration: BoxDecoration(color: background, borderRadius: radius),
          padding: padding,
          child: Opacity(
            opacity: enabled ? 1 : 0.45,
            child: IconTheme(
              data: IconThemeData(color: foreground, size: glyph),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (busy) ...[
                    SizedBox.square(
                      dimension: glyph,
                      child: AppMotion.reducedOf(context)
                          ? const AppIcon(AppIconType.loaderCircle)
                          : CircularProgressIndicator(color: foreground, strokeWidth: 2),
                    ),
                    SizedBox(width: gap),
                  ] else if (icon case final icon?) ...[
                    ExcludeSemantics(child: icon),
                    SizedBox(width: gap),
                  ],
                  Flexible(
                    child: ExcludeSemantics(
                      child: Text(label, textAlign: TextAlign.center, style: labelStyle),
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
