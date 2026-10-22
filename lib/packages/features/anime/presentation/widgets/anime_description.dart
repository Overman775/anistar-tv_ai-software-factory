import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';

/// The scrollable details page shows the complete story when height is unbounded.
class AnimeDescription extends StatelessWidget {
  const AnimeDescription({required this.description, super.key});

  final String description;

  @override
  Widget build(BuildContext context) {
    final style = AppContentTypography.descriptionOf(context)?.copyWith(color: AppPalette.textSecondary);
    final lineHeight = MediaQuery.textScalerOf(context).scale(style?.fontSize ?? 18) * (style?.height ?? 1.45);

    return LayoutBuilder(
      builder: (context, constraints) => Align(
        alignment: Alignment.topLeft,
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: TvTypography.proseMaxWidth),
          child: Text(
            description,
            maxLines: constraints.hasBoundedHeight ? (constraints.maxHeight / lineHeight).floor().clamp(1, 7) : null,
            overflow: constraints.hasBoundedHeight ? TextOverflow.ellipsis : TextOverflow.clip,
            style: style,
          ),
        ),
      ),
    );
  }
}
