import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';

class PlayerChoicesDialog<T> extends StatefulWidget {
  const PlayerChoicesDialog({
    required this.title,
    required this.choices,
    required this.selected,
    required this.label,
    super.key,
  });

  final List<T> choices;
  final String Function(T) label;
  final T selected;
  final String title;

  @override
  State<PlayerChoicesDialog<T>> createState() => _PlayerChoicesDialogState<T>();
}

class _PlayerChoicesDialogState<T> extends State<PlayerChoicesDialog<T>> {
  double _rowHeight = 64;
  ScrollController? _scrollController;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _rowHeight = TvChoiceTile.rowExtentOf(context);
    final selectedIndex = widget.choices.indexOf(widget.selected);
    _scrollController ??= ScrollController(
      initialScrollOffset: (selectedIndex * _rowHeight - _rowHeight * 2).clamp(
        0.0,
        (widget.choices.length * _rowHeight - 320).clamp(0.0, double.infinity),
      ),
    );
  }

  @override
  void dispose() {
    _scrollController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppActionSheet(
    title: widget.title,
    child: ListView(
      controller: _scrollController,
      itemExtent: _rowHeight,
      padding: EdgeInsets.zero,
      children: widget.choices
          .map(
            (choice) => TvChoiceTile(
              autofocus: choice == widget.selected,
              selected: choice == widget.selected,
              label: widget.label(choice),
              onPressed: () => Navigator.of(context).pop(choice),
            ),
          )
          .toList(growable: false),
    ),
  );
}
