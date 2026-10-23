import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';

import '../../../catalog/domain/models/catalog_filter.dart';
import 'anime_detail_filter_groups.dart';
import 'anime_filter_row.dart';

class AnimeDetailFilterActions extends StatelessWidget {
  const AnimeDetailFilterActions({
    required this.groups,
    required this.focusNodes,
    required this.onSelected,
    required this.onFocused,
    super.key,
  });

  final AnimeDetailFilterGroups groups;
  final Map<String, FocusNode> focusNodes;
  final ValueChanged<CatalogFilter> onSelected;
  final ValueChanged<int> onFocused;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    if (groups.genres.isNotEmpty || groups.genreText.isNotEmpty) {
      rows.add(
        AnimeFilterRow(
          heading: 'Жанры',
          filters: groups.genres,
          staticLabels: groups.genreText,
          focusNodes: focusNodes,
          filterIndices: groups.indices,
          onSelected: onSelected,
          onFocused: onFocused,
        ),
      );
    }
    if (groups.director case final director?) {
      rows.add(
        AnimeFilterRow(
          heading: 'Режиссёр',
          filters: [director],
          focusNodes: focusNodes,
          filterIndices: groups.indices,
          onSelected: onSelected,
          onFocused: onFocused,
        ),
      );
    } else if (groups.directorText case final director?) {
      rows.add(
        AnimeFilterRow(
          heading: 'Режиссёр',
          filters: const [],
          staticLabels: [director],
          focusNodes: focusNodes,
          filterIndices: groups.indices,
          onSelected: onSelected,
          onFocused: onFocused,
        ),
      );
    }
    if (groups.remaining.isNotEmpty) {
      rows.add(
        AnimeFilterRow(
          heading: 'Категории',
          filters: groups.remaining,
          focusNodes: focusNodes,
          filterIndices: groups.indices,
          onSelected: onSelected,
          onFocused: onFocused,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < rows.length; index++) ...[
          if (index > 0) const SizedBox(height: AppSpacing.md),
          rows[index],
        ],
      ],
    );
  }
}
