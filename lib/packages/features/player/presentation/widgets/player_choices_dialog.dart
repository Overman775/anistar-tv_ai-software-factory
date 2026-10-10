import 'package:material_ui/material_ui.dart';

class PlayerChoicesDialog<T> extends StatelessWidget {
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
  Widget build(BuildContext context) => SimpleDialog(
    title: Text(title),
    children: [
      SizedBox(
        width: 360,
        height: choices.length <= 4 ? choices.length * 64 : 320,
        child: ListView(
          children: choices
              .map(
                (choice) => ListTile(
                  autofocus: choice == selected,
                  selected: choice == selected,
                  title: Text(label(choice)),
                  trailing: choice == selected ? const Icon(Icons.check) : null,
                  onTap: () => Navigator.of(context).pop(choice),
                ),
              )
              .toList(growable: false),
        ),
      ),
    ],
  );
}
