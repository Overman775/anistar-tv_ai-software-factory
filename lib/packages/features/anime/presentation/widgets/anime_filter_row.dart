import 'dart:async';
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';

import '../../../catalog/domain/models/catalog_filter.dart';
import 'anime_filter_chip.dart';
import 'anime_static_chip.dart';

class AnimeFilterRow extends StatelessWidget {
  const AnimeFilterRow({
    required this.filters,
    required this.focusNodes,
    required this.onSelected,
    required this.onFocused,
    this.heading,
    this.filterIndices = const {},
    this.staticLabels = const [],
    this.inline = false,
    super.key,
  });

  final List<CatalogFilter> filters;
  final Map<String, FocusNode> focusNodes;
  final ValueChanged<CatalogFilter> onSelected;
  final ValueChanged<int> onFocused;
  final String? heading;
  final Map<String, int> filterIndices;
  final List<String> staticLabels;
  final bool inline;

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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.bodyMedium;
    final textHeight = MediaQuery.textScalerOf(context).scale(style?.fontSize ?? 16) * (style?.height ?? 1.4);
    final headingText = heading;

    if (inline) {
      final filter = filters.single;

      return AnimeFilterChip(
        filter: filter,
        focusNodes: focusNodes,
        index: filterIndices[filter.path] ?? 0,
        maxWidth: 360,
        onSelected: onSelected,
        onFocused: _focusChanged,
      );
    }

    if (headingText != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(headingText, style: theme.textTheme.labelLarge?.copyWith(color: AppPalette.textSecondary)),
          const SizedBox(height: AppSpacing.sm),
          LayoutBuilder(
            builder: (context, constraints) => Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final filter in filters)
                  AnimeFilterChip(
                    filter: filter,
                    focusNodes: focusNodes,
                    index: filterIndices[filter.path] ?? filters.indexOf(filter),
                    maxWidth: constraints.maxWidth,
                    onSelected: onSelected,
                    onFocused: _focusChanged,
                  ),
                for (final label in staticLabels) AnimeStaticChip(label: label, maxWidth: constraints.maxWidth),
              ],
            ),
          ),
        ],
      );
    }

    return SizedBox(
      height: math.max(48, textHeight + 20),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (var i = 0; i < filters.length; i++)
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.sm),
                child: AnimeFilterChip(
                  filter: filters[i],
                  focusNodes: focusNodes,
                  index: filterIndices[filters[i].path] ?? i,
                  maxWidth: 360,
                  onSelected: onSelected,
                  onFocused: _focusChanged,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
