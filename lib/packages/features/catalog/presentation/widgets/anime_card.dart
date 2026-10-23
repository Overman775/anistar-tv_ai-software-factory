import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';

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
  });

  final AnimeSummary anime;
  final bool autofocus;
  final bool? isFavorite;
  final bool showFavorite;
  final ValueChanged<bool>? onFocusChanged;
  final VoidCallback onTap;
  final VoidCallback? onLongPressed;

  @override
  Widget build(BuildContext context) => MediaCard(
    label: anime.title,
    caption: anime.year,
    imageUrl: anime.posterUri?.toString(),
    heroTag: 'anime-poster-${anime.id}',
    autofocus: autofocus,
    onFocusChanged: onFocusChanged,
    onPressed: onTap,
    onLongPressed: onLongPressed,
    showBookmark: showFavorite && (isFavorite ?? anime.isFavorite) == true,
    badges: [AnimeRatingBadge(rating: anime.rating)],
  );
}
