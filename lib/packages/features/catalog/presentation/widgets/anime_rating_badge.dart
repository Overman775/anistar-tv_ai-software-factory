import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';

/// Projects the site's optional score without inventing a missing rating.
class AnimeRatingBadge extends StatelessWidget {
  const AnimeRatingBadge({required this.rating, super.key});

  final double? rating;

  @override
  Widget build(BuildContext context) {
    final value = rating;
    if (value == null || !value.isFinite || value < 0 || value > 10) {
      return const SizedBox.shrink();
    }

    final label = value.toStringAsFixed(1).replaceAll('.', ',');

    return AppMetadataBadge(icon: Icons.grade_rounded, label: label, semanticLabel: 'Рейтинг $label из 10');
  }
}
