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
  final ValueChanged<bool>? onFocusChanged;
  final VoidCallback? onLongPressed;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) => TvFocusable(
    focusNode: focusNode,
    autofocus: autofocus,
    onPressed: onPressed,
    onLongPressed: onLongPressed,
    onFocusChanged: onFocusChanged,
    semanticLabel: semanticLabel,
    builder: (context, focused) {
      final card = variant == TvFocusTileVariant.card;
      final radius = card ? AppRadii.large : AppRadii.medium;
      final decoration = AppFocusStyle.decoration(
        focused: focused,
        selected: selected,
        radius: radius,
        restingColor: card ? AppPalette.surface : Colors.transparent,
      );

      return AnimatedScale(
        scale: card && focused && !AppMotion.reducedOf(context) ? 1.035 : 1,
        duration: AppMotion.durationOf(context, AppMotion.fast),
        curve: AppMotion.enterCurve,
        child: AnimatedContainer(
          duration: AppMotion.durationOf(context, AppMotion.fast),
          curve: AppMotion.enterCurve,
          decoration: decoration.copyWith(border: const Border()),
          // Paint the stroke over the image. Its outer contour matches the
          // clip; BoxBorder deflates its inner contour by the stroke width.
          // Neither focus nor the outline changes the content's bounds.
          foregroundDecoration: BoxDecoration(
            borderRadius: radius,
            border: focused || !card
                ? decoration.border
                : const Border.fromBorderSide(BorderSide(color: AppPalette.outline)),
          ),
          child: ClipRRect(
            borderRadius: radius,
            child: Builder(builder: (context) => builder(context, focused)),
          ),
        ),
      );
    },
  );
}

enum TvFocusTileVariant { card, row }
