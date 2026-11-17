import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:sizer/sizer.dart';
import 'package:ui_kit/ui_kit.dart';

import '../../../catalog/domain/models/catalog_filter.dart';

class AnimeFilterChip extends StatelessWidget {
  const AnimeFilterChip({
    required this.filter,
    required this.label,
    required this.focusNodes,
    required this.index,
    required this.maxWidth,
    required this.onSelected,
    required this.onFocused,
    super.key,
  });

  final CatalogFilter filter;
  final String label;
  final Map<String, FocusNode> focusNodes;
  final int index;
  final double maxWidth;
  final ValueChanged<CatalogFilter> onSelected;
  final void Function(BuildContext context, int index, bool focused) onFocused;

  @override
  Widget build(BuildContext context) => Builder(
    builder: (chipContext) {
      final tv = AppLayoutScope.isTvOf(context);
      final minimum = tv ? AppSizes.adaptiveTvMetadataControl : AppSizes.metadataControl;
      final glyph = tv ? 2.23.vmin.clamp(14.0, 16.0) : 16.0;
      final horizontal = tv ? 0.63.w.clamp(6.0, 8.0) : AppSpacing.sm;
      final vertical = tv ? 0.56.h.clamp(4.0, 6.0) : AppSpacing.xs;
      final style =
          (tv
                  ? AppTypography.metadataControlTextOf(context)
                  : Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: 16))
              ?.copyWith(color: AppPalette.textPrimary);

      return TvFocusable(
        focusNode: focusNodes.putIfAbsent(filter.path, () => FocusNode(debugLabel: filter.label)),
        semanticLabel: 'Показать аниме: $label',
        onPressed: () => onSelected(filter),
        onFocusChanged: (focused) => onFocused(chipContext, index, focused),
        builder: (context, focused) => ConstrainedBox(
          constraints: const BoxConstraints(minWidth: AppSizes.touchControl, minHeight: AppSizes.touchControl),
          child: Center(
            widthFactor: 1,
            child: AppFocusBorder(
              focused: focused,
              child: AnimatedContainer(
                duration: AppMotion.durationOf(context, AppMotion.fast),
                decoration: AppFocusStyle.decoration(
                  focused: focused,
                  restingColor: AppPalette.surfaceElevated,
                ).copyWith(border: const Border()),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: minimum, maxWidth: math.min(360, maxWidth)),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: horizontal, vertical: vertical),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AppIcon(AppIconType.listFilter, size: glyph),
                        const SizedBox(width: AppSpacing.xs),
                        Flexible(child: Text(label, style: style)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}
