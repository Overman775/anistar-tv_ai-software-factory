import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
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
    builder: (chipContext) => TvFocusable(
      focusNode: focusNodes.putIfAbsent(filter.path, () => FocusNode(debugLabel: filter.label)),
      semanticLabel: 'Показать аниме: $label',
      onPressed: () => onSelected(filter),
      onFocusChanged: (focused) => onFocused(chipContext, index, focused),
      builder: (context, focused) => ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: AppLayoutScope.isTvOf(context) ? AppSizes.metadataControl : AppSizes.touchControl,
        ),
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
                constraints: BoxConstraints(minHeight: AppSizes.metadataControl, maxWidth: math.min(360, maxWidth)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const AppIcon(AppIconType.listFilter, size: 16),
                      const SizedBox(width: AppSpacing.xs),
                      Flexible(
                        child: Text(label, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: 16)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
