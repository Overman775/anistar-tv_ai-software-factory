import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';

import '../../../catalog/domain/models/catalog_filter.dart';

class AnimeFilterRow extends StatelessWidget {
  const AnimeFilterRow({
    required this.filters,
    required this.focusNodes,
    required this.onSelected,
    required this.onFocused,
    super.key,
  });

  final List<CatalogFilter> filters;
  final Map<String, FocusNode> focusNodes;
  final ValueChanged<CatalogFilter> onSelected;
  final ValueChanged<int> onFocused;

  void _focusChanged(BuildContext context, int index, bool focused) {
    if (!focused) {
      return;
    }
    onFocused(index);
    unawaited(
      Scrollable.ensureVisible(context, alignment: 0.5, duration: AppMotion.durationOf(context, AppMotion.fast)),
    );
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 48,
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < filters.length; i++)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: Builder(
                builder: (chipContext) {
                  final filter = filters[i];

                  return TvFocusable(
                    focusNode: focusNodes.putIfAbsent(filter.path, () => FocusNode(debugLabel: filter.label)),
                    semanticLabel: 'Аниме: ${filter.label}',
                    onPressed: () => onSelected(filter),
                    onFocusChanged: (focused) => _focusChanged(chipContext, i, focused),
                    builder: (context, focused) => AnimatedContainer(
                      duration: AppMotion.durationOf(context, AppMotion.fast),
                      decoration: AppFocusStyle.decoration(
                        focused: focused,
                        restingColor: AppPalette.surfaceElevated,
                        radius: AppRadii.pill,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        child: Text(filter.label, style: const TextStyle(fontSize: 16, color: AppPalette.textPrimary)),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    ),
  );
}
