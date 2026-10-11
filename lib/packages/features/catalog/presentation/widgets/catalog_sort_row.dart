import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';

class CatalogSortRow extends StatelessWidget {
  const CatalogSortRow({
    required this.focusNode,
    required this.label,
    required this.onPressed,
    this.selected = false,
    this.autofocus = false,
    super.key,
  });

  final FocusNode focusNode;
  final String label;
  final VoidCallback onPressed;
  final bool selected;
  final bool autofocus;

  @override
  Widget build(BuildContext context) => !AppLayoutScope.isTvOf(context)
      ? ListTile(
          title: Text(label),
          selected: selected,
          trailing: selected ? const Icon(Icons.check) : null,
          onTap: onPressed,
        )
      : TvChoiceTile(
          focusNode: focusNode,
          label: label,
          onPressed: onPressed,
          selected: selected,
          autofocus: autofocus,
        );
}
