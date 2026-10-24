import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';

import '../../../common/presentation/rating_presentation.dart';

/// Projects the site's optional score without inventing a missing rating.
class AnimeRatingBadge extends StatelessWidget {
  const AnimeRatingBadge({required this.rating, super.key});

  final double? rating;

  @override
  Widget build(BuildContext context) {
    final value = RatingPresentation.from(rating);
    if (value == null) {
      return const SizedBox.shrink();
    }

    return AppMetadataBadge(icon: Icons.grade_rounded, label: value.label, semanticLabel: value.semanticLabel);
  }
}
