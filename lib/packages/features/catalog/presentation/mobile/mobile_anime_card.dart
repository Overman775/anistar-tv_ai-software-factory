import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';

import '../../../common/presentation/rating_presentation.dart';
import '../../domain/models/anime_summary.dart';

/// The common poster surface with a discoverable touch action.
class MobileAnimeCard extends StatelessWidget {
  const MobileAnimeCard({
    required this.anime,
    required this.onTap,
    required this.onActions,
    this.isFavorite,
    this.showFavorite = true,
    this.showRating = false,
    super.key,
  });

  final AnimeSummary anime;
  final VoidCallback onTap;
  final VoidCallback onActions;
  final bool? isFavorite;
  final bool showFavorite;
  final bool showRating;

  @override
  Widget build(BuildContext context) => MediaCard(
    label: anime.title,
    caption: anime.year,
    showCaption: false,
    showBookmark: showFavorite && (isFavorite ?? anime.isFavorite) == true,
    ratingLabel: showRating ? RatingPresentation.from(anime.rating)?.label : null,
    imageUrl: anime.posterUri?.toString(),
    heroTag: 'anime-poster-${anime.id}',
    onPressed: onTap,
    onLongPressed: onActions,
  );
}
