import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';

class CatalogInspectorRating extends StatelessWidget {
  const CatalogInspectorRating({required this.rating, super.key});

  final double? rating;

  @override
  Widget build(BuildContext context) {
    final value = rating;
    if (value == null || !value.isFinite || value < 0 || value > 10) {
      return const SizedBox.shrink();
    }
    final label = value.toStringAsFixed(1).replaceAll('.', ',');
    final textTheme = Theme.of(context).textTheme;

    return Semantics(
      label: 'Рейтинг $label из 10',
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AppIcon(AppIconType.star, size: 20),
            const SizedBox(width: AppSpacing.xs),
            Text(label, style: textTheme.titleMedium),
            const SizedBox(width: AppSpacing.xs),
            Text('/ 10', style: textTheme.bodyMedium?.copyWith(color: AppPalette.textSecondary)),
          ],
        ),
      ),
    );
  }
}
