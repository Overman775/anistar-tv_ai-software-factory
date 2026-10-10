import 'dart:async';

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
  static const _rowHeight = 64.0;
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    final selectedIndex = widget.choices.indexOf(widget.selected);
    _scrollController = ScrollController(
      initialScrollOffset: (selectedIndex * _rowHeight - _rowHeight * 2).clamp(
        0.0,
        (widget.choices.length * _rowHeight - 320).clamp(0.0, double.infinity),
      ),
    );
  }

  void _revealChoice(BuildContext context, bool focused) {
    if (focused) {
      unawaited(
        Scrollable.ensureVisible(context, duration: AppMotion.durationOf(context, AppMotion.fast), alignment: 0.5),
      );
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SimpleDialog(
    title: Text(widget.title),
    children: [
      SizedBox(
        width: 420,
        height: widget.choices.length <= 4 ? widget.choices.length * _rowHeight : 320,
        child: ListView(
          controller: _scrollController,
          itemExtent: _rowHeight,
          padding: EdgeInsets.zero,
          children: widget.choices
              .map(
                (choice) => Builder(
                  builder: (choiceContext) => Focus(
                    canRequestFocus: false,
                    onFocusChange: (focused) => _revealChoice(choiceContext, focused),
                    child: ListTile(
                      autofocus: choice == widget.selected,
                      selected: choice == widget.selected,
                      title: Text(widget.label(choice), maxLines: 1, overflow: TextOverflow.ellipsis),
                      trailing: choice == widget.selected ? const Icon(Icons.check) : null,
                      onTap: () => Navigator.of(context).pop(choice),
                    ),
                  ),
                ),
              )
              .toList(growable: false),
        ),
      ),
    ],
  );
}
