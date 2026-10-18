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
  });

  final AnimeSummary anime;
  final bool autofocus;
  final bool? isFavorite;
  final ValueChanged<bool>? onFocusChanged;
  final VoidCallback onTap;
  final VoidCallback? onLongPressed;

  @override
  Widget build(BuildContext context) {
    final posterUri = anime.posterUri;
    final posterUrl = posterUri?.toString();

    return TvFocusTile(
      autofocus: autofocus,
      onFocusChanged: onFocusChanged,
      onPressed: onTap,
      onLongPressed: onLongPressed,
      semanticLabel: anime.title,
      builder: (context, focused) {
        final theme = Theme.of(context);
        final textTheme = theme.textTheme;

        return Stack(
          fit: StackFit.expand,
          children: [
            TvPosterHero(
              tag: 'anime-poster-${anime.id}',
              imageUrl: posterUri?.hasScheme == true ? posterUrl : null,
              semanticLabel: anime.title,
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x00000000), Color(0x18000000), Color(0xF7080B14)],
                  stops: [0, 0.48, 1],
                ),
              ),
            ),
            Positioned(
              left: AppSpacing.md,
              right: AppSpacing.md,
              bottom: AppSpacing.md,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (anime.year case final year?)
                    Text(year, style: textTheme.labelLarge?.copyWith(color: AppPalette.secondary)),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    anime.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.titleSmall?.copyWith(color: AppPalette.textPrimary, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            Positioned(
              top: AppSpacing.sm,
              right: AppSpacing.sm,
              child: AnimeRatingBadge(rating: anime.rating),
            ),
            Positioned(
              top: AppSpacing.sm,
              left: AppSpacing.sm,
              child: AnimatedSwitcher(
                duration: AppMotion.durationOf(context, AppMotion.fast),
                switchInCurve: AppMotion.enterCurve,
                switchOutCurve: AppMotion.exitCurve,
                child: (isFavorite ?? anime.isFavorite ?? false)
                    ? AppMetadataBadge(
                        key: ValueKey('favorite-${anime.id}'),
                        icon: Icons.star_rounded,
                        semanticLabel: 'В избранном',
                      )
                    : const SizedBox.shrink(key: ValueKey(false)),
              ),
            ),
          ],
        );
      },
    );
  }
}
