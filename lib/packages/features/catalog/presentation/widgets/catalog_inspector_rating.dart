import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';

import '../../../common/presentation/rating_presentation.dart';

class CatalogInspectorRating extends StatelessWidget {
  const CatalogInspectorRating({required this.rating, super.key});

  final double? rating;

  @override
  Widget build(BuildContext context) {
    final value = RatingPresentation.from(rating);
    if (value == null) {
      return const SizedBox.shrink();
    }
    final textTheme = Theme.of(context).textTheme;

    return Semantics(
      label: value.semanticLabel,
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AppIcon(AppIconType.star, size: 20),
            const SizedBox(width: AppSpacing.xs),
            Text(value.label, style: textTheme.titleMedium),
            const SizedBox(width: AppSpacing.xs),
            Text('/ 10', style: textTheme.bodyMedium?.copyWith(color: AppPalette.textSecondary)),
          ],
        ),
      ),
    );
  }
}
