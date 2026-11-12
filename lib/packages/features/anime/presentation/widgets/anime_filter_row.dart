import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';

import '../../../catalog/domain/models/catalog_filter.dart';
import 'anime_detail_filter_groups.dart';
import 'anime_filter_chip.dart';

class AnimeFilterRow extends StatelessWidget {
  const AnimeFilterRow({
    required this.filters,
    required this.focusNodes,
    required this.onSelected,
    this.onFocused,
    super.key,
  }) : values = const [],
       filterIndices = const {};

  const AnimeFilterRow.metadata({
    required this.values,
    required this.focusNodes,
    required this.onSelected,
    required this.filterIndices,
    this.onFocused,
    super.key,
  }) : filters = null;

  final List<CatalogFilter>? filters;
  final List<AnimeMetadataValue> values;
  final Map<String, FocusNode> focusNodes;
  final ValueChanged<CatalogFilter> onSelected;
  final ValueChanged<int>? onFocused;
  final Map<String, int> filterIndices;

  void _focusChanged(BuildContext context, int index, bool focused) {
    if (!focused || ModalRoute.isCurrentOf(context) == false) return;
    onFocused?.call(index);
    unawaited(Scrollable.ensureVisible(context, duration: AppMotion.durationOf(context, AppMotion.fast)));
  }

  @override
  Widget build(BuildContext context) {
    if (filters case final rowFilters?) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          spacing: AppSpacing.sm,
          children: [for (final (index, filter) in rowFilters.indexed) _chip(filter, filter.label, index, 360)],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) => Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: [
          for (final value in values)
            if (value.filter case final filter?)
              _chip(filter, value.label, filterIndices[filter.path] ?? 0, constraints.maxWidth)
            else
              Text(value.label, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: 16)),
        ],
      ),
    );
  }

  Widget _chip(CatalogFilter filter, String label, int index, double maxWidth) => AnimeFilterChip(
    filter: filter,
    label: label,
    focusNodes: focusNodes,
    index: index,
    maxWidth: maxWidth,
    onSelected: onSelected,
    onFocused: _focusChanged,
  );
}
