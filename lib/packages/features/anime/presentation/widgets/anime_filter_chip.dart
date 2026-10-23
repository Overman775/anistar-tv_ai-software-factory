import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';

import '../../../catalog/domain/models/catalog_filter.dart';

class AnimeFilterChip extends StatelessWidget {
  const AnimeFilterChip({
    required this.filter,
    required this.focusNodes,
    required this.index,
    required this.maxWidth,
    required this.onSelected,
    required this.onFocused,
    super.key,
  });

  final CatalogFilter filter;
  final Map<String, FocusNode> focusNodes;
  final int index;
  final double maxWidth;
  final ValueChanged<CatalogFilter> onSelected;
  final void Function(BuildContext context, int index, bool focused) onFocused;

  @override
  Widget build(BuildContext context) => Builder(
    builder: (chipContext) => TvFocusable(
      focusNode: focusNodes.putIfAbsent(filter.path, () => FocusNode(debugLabel: filter.label)),
      semanticLabel: 'Показать аниме: ${filter.label}',
      onPressed: () => onSelected(filter),
      onFocusChanged: (focused) => onFocused(chipContext, index, focused),
      builder: (context, focused) => AppFocusBorder(
        focused: focused,
        child: AnimatedContainer(
          duration: AppMotion.durationOf(context, AppMotion.fast),
          decoration: AppFocusStyle.decoration(
            focused: focused,
            restingColor: AppPalette.surfaceElevated,
          ).copyWith(border: const Border()),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: math.min(360, maxWidth)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const AppIcon(AppIconType.listFilter, size: 20),
                  const SizedBox(width: AppSpacing.sm),
                  Flexible(
                    child: Text(
                      filter.label,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppPalette.textPrimary),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
