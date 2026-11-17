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
  Size? _lastViewport;
  double? _lastRowHeight;
  ScrollController? _scrollController;

  bool get _adaptiveTv => AppLayoutScope.isTvOf(context);

  double _offsetFor(double rowHeight) {
    final selectedIndex = widget.choices.indexOf(widget.selected);

    return (selectedIndex * rowHeight - rowHeight * 2).clamp(
      0.0,
      (widget.choices.length * rowHeight - 320).clamp(0.0, double.infinity),
    );
  }

  void _revealAfterResize(Size viewport) {
    if (_lastViewport == viewport && _lastRowHeight == _rowHeight) return;
    _lastViewport = viewport;
    _lastRowHeight = _rowHeight;
    final controller = _scrollController;
    if (controller == null || !controller.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || controller != _scrollController || !controller.hasClients) return;
      final target = _offsetFor(_rowHeight);
      controller.jumpTo(target.clamp(controller.position.minScrollExtent, controller.position.maxScrollExtent));
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _rowHeight = TvChoiceTile.rowExtentOf(context, adaptiveTv: AppLayoutScope.isTvOf(context));
    _scrollController ??= ScrollController(initialScrollOffset: _offsetFor(_rowHeight));
  }

  @override
  void dispose() {
    _scrollController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppActionSheet(
    title: widget.title,
    expandChild: true,
    adaptiveTv: true,
    child: LayoutBuilder(
      builder: (context, constraints) {
        _revealAfterResize(constraints.biggest);

        return ListView(
          controller: _scrollController,
          itemExtent: _rowHeight,
          padding: EdgeInsets.zero,
          children: widget.choices
              .map(
                (choice) => TvChoiceTile(
                  autofocus: choice == widget.selected,
                  selected: choice == widget.selected,
                  adaptiveTv: _adaptiveTv,
                  label: widget.label(choice),
                  onPressed: () => Navigator.of(context).pop(choice),
                ),
              )
              .toList(growable: false),
        );
      },
    ),
  );
}
