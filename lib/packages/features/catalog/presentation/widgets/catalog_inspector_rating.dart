import 'package:material_ui/material_ui.dart';
import 'package:sizer/sizer.dart';
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
    final style = AppTypography.metadataTextOf(context);

    return Semantics(
      label: value.semanticLabel,
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppIcon(AppIconType.star, size: 2.78.vmin.clamp(18.0, 20.0)),
            const SizedBox(width: AppSpacing.xs),
            Text(value.label, style: style?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(width: AppSpacing.xs),
            Text('/ 10', style: style?.copyWith(color: AppPalette.textSecondary)),
          ],
        ),
      ),
    );
  }
}
