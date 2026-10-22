import 'package:material_ui/material_ui.dart';

import '../theme/app_focus_style.dart';
import '../theme/app_palette.dart';
import 'tv_focusable.dart';

/// Shared focus geometry and activation for image cards and choice rows.
class TvFocusTile extends StatelessWidget {
  const TvFocusTile({
    required this.builder,
    required this.onPressed,
    this.variant = TvFocusTileVariant.card,
    this.focusNode,
    this.autofocus = false,
    this.selected = false,
    this.enabled = true,
    this.busy = false,
    this.onFocusChanged,
    this.onLongPressed,
    this.semanticLabel,
    super.key,
  });

  final TvFocusBuilder builder;
  final VoidCallback onPressed;
  final TvFocusTileVariant variant;
  final FocusNode? focusNode;
  final bool autofocus;
  final bool selected;
  final bool enabled;
  final bool busy;
  final ValueChanged<bool>? onFocusChanged;
  final VoidCallback? onLongPressed;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    child: TvFocusable(
      focusNode: focusNode,
      autofocus: autofocus,
      enabled: enabled,
      busy: busy,
      onPressed: onPressed,
      onLongPressed: onLongPressed,
      onFocusChanged: onFocusChanged,
      semanticLabel: semanticLabel,
      stateBuilder: (context, state) {
        final focused = state.focused;
        final card = variant == TvFocusTileVariant.card;
        final radius = card ? AppRadii.large : AppRadii.medium;
        final decoration = AppFocusStyle.decoration(
          focused: focused || state.hovered,
          pressed: state.pressed,
          selected: selected,
          radius: radius,
          restingColor: card ? AppPalette.surface : Colors.transparent,
        );

        return AnimatedScale(
          scale: card && focused && !state.pressed && !AppMotion.reducedOf(context) ? AppSizes.cardFocusScale : 1,
          duration: AppMotion.durationOf(context, focused ? AppMotion.fast : AppMotion.focusExit),
          curve: focused ? AppMotion.enterCurve : AppMotion.exitCurve,
          child: AnimatedContainer(
            duration: AppMotion.durationOf(context, focused ? AppMotion.fast : AppMotion.focusExit),
            curve: focused ? AppMotion.enterCurve : AppMotion.exitCurve,
            decoration: decoration.copyWith(border: const Border()),
            // Paint the stroke over the image. Its outer contour matches the
            // clip; BoxBorder deflates its inner contour by the stroke width.
            // Neither focus nor the outline changes the content's bounds.
            foregroundDecoration: BoxDecoration(
              color: card && state.pressed ? AppPalette.textPrimary.withValues(alpha: 0.12) : Colors.transparent,
              borderRadius: radius,
              border: switch ((focused || !card, selected)) {
                (true, _) => decoration.border,
                (_, true) => const Border.fromBorderSide(BorderSide(color: AppPalette.textSecondary, width: 2)),
                _ => const Border.fromBorderSide(BorderSide(color: AppPalette.outline)),
              },
            ),
            child: Opacity(
              opacity: enabled ? 1 : 0.45,
              child: ClipRRect(
                borderRadius: radius,
                child: Builder(builder: (context) => builder(context, focused)),
              ),
            ),
          ),
        );
      },
    ),
  );
}

enum TvFocusTileVariant { card, row }
