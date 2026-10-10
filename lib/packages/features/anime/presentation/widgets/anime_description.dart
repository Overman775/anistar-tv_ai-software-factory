import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';

/// Keeps ellipsis on the last visible line above the hero actions.
class AnimeDescription extends StatelessWidget {
  const AnimeDescription({required this.description, super.key});

  final String description;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppPalette.textSecondary);
    final lineHeight = MediaQuery.textScalerOf(context).scale(style?.fontSize ?? 18) * (style?.height ?? 1.45);

    return LayoutBuilder(
      builder: (context, constraints) => Text(
        description,
        maxLines: (constraints.maxHeight / lineHeight).floor().clamp(1, 7),
        overflow: TextOverflow.ellipsis,
        style: style,
      ),
    );
  }
}
