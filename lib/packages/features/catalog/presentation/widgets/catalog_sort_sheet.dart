import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';

import '../../domain/models/catalog_sort.dart';
import 'catalog_sort_row.dart';

String sortCriterionLabel(CatalogSortCriterion criterion) => switch (criterion) {
  CatalogSortCriterion.date => 'По дате',
  CatalogSortCriterion.popularity => 'По популярности',
  CatalogSortCriterion.visits => 'По посещаемости',
  CatalogSortCriterion.comments => 'По комментариям',
  CatalogSortCriterion.title => 'По алфавиту',
};

String sortDirectionLabel(CatalogSort sort) => switch (sort.criterion) {
  CatalogSortCriterion.date => sort.ascending ? 'Сначала старые' : 'Сначала новые',
  CatalogSortCriterion.title => sort.ascending ? 'А → Я' : 'Я → А',
  _ => sort.ascending ? 'По возрастанию' : 'По убыванию',
};

String catalogSortLabel(CatalogSort sort) => '${sortCriterionLabel(sort.criterion)} · ${sortDirectionLabel(sort)}';

class CatalogSortSheet extends StatefulWidget {
  const CatalogSortSheet({required this.selected, super.key});

  final CatalogSort selected;

  @override
  State<CatalogSortSheet> createState() => _CatalogSortSheetState();
}

class _CatalogSortSheetState extends State<CatalogSortSheet> {
  late CatalogSort _draft = widget.selected;
  final _nodes = List.generate(9, (index) => FocusNode(debugLabel: 'sort-option-$index'));

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape) {
      if (event is KeyDownEvent) {
        Navigator.of(context).pop();
      }

      return KeyEventResult.handled;
    }
    if (![
      LogicalKeyboardKey.arrowUp,
      LogicalKeyboardKey.arrowDown,
      LogicalKeyboardKey.arrowRight,
      LogicalKeyboardKey.arrowLeft,
    ].contains(key)) {
      return KeyEventResult.ignored;
    }
    if (event is KeyDownEvent || event is KeyRepeatEvent) {
      final index = _nodes.indexWhere((item) => item.hasFocus);
      final delta = switch (key) {
        LogicalKeyboardKey.arrowDown => 1,
        LogicalKeyboardKey.arrowUp => -1,
        _ => 0,
      };
      _nodes[(index + delta).clamp(0, _nodes.length - 1)].requestFocus();
    }

    return KeyEventResult.handled;
  }

  @override
  void dispose() {
    for (final node in _nodes) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppActionSheet(
    title: 'Сортировка',
    closeOnLeft: false,
    child: Focus(
      canRequestFocus: false,
      onKeyEvent: _handleKey,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final criterion in CatalogSortCriterion.values)
              CatalogSortRow(
                focusNode: _nodes[criterion.index],
                autofocus: criterion == widget.selected.criterion,
                label: sortCriterionLabel(criterion),
                selected: _draft.criterion == criterion,
                onPressed: () => setState(() => _draft = (criterion: criterion, ascending: _draft.ascending)),
              ),
            const Padding(padding: EdgeInsets.only(top: 16, bottom: 8), child: Text('Порядок')),
            for (final ascending in [false, true])
              CatalogSortRow(
                focusNode: _nodes[ascending ? 6 : 5],
                label: sortDirectionLabel((criterion: _draft.criterion, ascending: ascending)),
                selected: _draft.ascending == ascending,
                onPressed: () => setState(() => _draft = (criterion: _draft.criterion, ascending: ascending)),
              ),
            const SizedBox(height: 16),
            CatalogSortRow(
              focusNode: _nodes[7],
              label: 'Применить',
              onPressed: () => Navigator.of(context).pop(_draft),
            ),
            CatalogSortRow(focusNode: _nodes[8], label: 'Отмена', onPressed: () => Navigator.of(context).pop()),
          ],
        ),
      ),
    ),
  );
}
