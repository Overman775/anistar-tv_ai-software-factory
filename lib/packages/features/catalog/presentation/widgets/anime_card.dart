import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';

import '../../../common/presentation/rating_presentation.dart';
import '../../domain/models/anime_summary.dart';
import 'anime_rating_badge.dart';

class AnimeCard extends StatelessWidget {
  const AnimeCard({
    required this.anime,
    required this.onTap,
    super.key,
    this.autofocus = false,
    this.onFocusChanged,
    this.onLongPressed,
    this.isFavorite,
    this.showFavorite = true,
    this.focusNode,
    this.rail = false,
    this.selected = false,
  });

  final AnimeSummary anime;
  final bool autofocus;
  final bool? isFavorite;
  final bool showFavorite;
  final FocusNode? focusNode;
  final bool rail;
  final bool selected;
  final ValueChanged<bool>? onFocusChanged;
  final VoidCallback onTap;
  final VoidCallback? onLongPressed;

  @override
  Widget build(BuildContext context) => MediaCard(
    label: anime.title,
    caption: rail ? null : anime.year,
    imageUrl: anime.posterUri?.toString(),
    heroTag: rail ? null : 'anime-poster-${anime.id}',
    focusNode: focusNode,
    autofocus: autofocus,
    onFocusChanged: onFocusChanged,
    onPressed: onTap,
    onLongPressed: onLongPressed,
    showBookmark: showFavorite && (isFavorite ?? anime.isFavorite) == true,
    badges: rail ? const [] : [AnimeRatingBadge(rating: anime.rating)],
    ratingLabel: rail ? RatingPresentation.from(anime.rating)?.label : null,
    selected: selected,
    scaleOnFocus: !rail,
  );
}
