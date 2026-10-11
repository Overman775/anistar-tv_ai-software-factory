import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';

import '../../domain/models/anime_summary.dart';

/// Touch composition: the title stays readable independently of the poster.
class MobileAnimeCard extends StatelessWidget {
  const MobileAnimeCard({
    required this.anime,
    required this.onTap,
    required this.onActions,
    this.isFavorite,
    super.key,
  });

  final AnimeSummary anime;
  final VoidCallback onTap;
  final VoidCallback onActions;
  final bool? isFavorite;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Expanded(
        child: Material(
          color: AppPalette.surfaceElevated,
          clipBehavior: Clip.antiAlias,
          borderRadius: AppRadii.large,
          child: InkWell(
            onTap: onTap,
            onLongPress: onActions,
            child: Stack(
              fit: StackFit.expand,
              children: [
                TvPosterHero(
                  tag: 'anime-poster-${anime.id}',
                  imageUrl: anime.posterUri?.hasScheme == true ? anime.posterUri?.toString() : null,
                  semanticLabel: anime.title,
                ),
                if (isFavorite ?? anime.isFavorite ?? false)
                  const Positioned(
                    left: 8,
                    top: 8,
                    child: Tooltip(
                      message: 'В избранном',
                      child: Icon(Icons.star_rounded, color: AppPalette.secondary),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      const SizedBox(height: 6),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: InkWell(
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(
                  anime.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
            ),
          ),
          SizedBox(
            width: 48,
            height: 48,
            child: IconButton(
              key: ValueKey('anime-actions-${anime.id}'),
              tooltip: 'Действия: ${anime.title}',
              onPressed: onActions,
              icon: const Icon(Icons.more_vert),
            ),
          ),
        ],
      ),
      Row(
        children: [
          Expanded(
            child: Text(
              anime.year ?? '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppPalette.textSecondary),
            ),
          ),
          if (anime.rating case final rating? when rating.isFinite && rating >= 0 && rating <= 10)
            Semantics(
              label: 'Рейтинг ${rating.toStringAsFixed(1)} из 10',
              excludeSemantics: true,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.grade_rounded, size: 16, color: AppPalette.secondary),
                  const SizedBox(width: 4),
                  Text(rating.toStringAsFixed(1), style: Theme.of(context).textTheme.labelMedium),
                ],
              ),
            ),
        ],
      ),
    ],
  );
}
