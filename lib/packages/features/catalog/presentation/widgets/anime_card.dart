import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';

import '../../domain/models/anime_summary.dart';

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
    final posterUrl = posterUri.toString();

    return TvFocusable(
      autofocus: autofocus,
      onFocusChanged: onFocusChanged,
      onPressed: onTap,
      onLongPressed: onLongPressed,
      semanticLabel: anime.title,
      builder: (context, focused) {
        final theme = Theme.of(context);
        final primary = theme.colorScheme.primary;
        final textTheme = theme.textTheme;

        return AnimatedScale(
          duration: AppMotion.fast,
          scale: focused ? 1.055 : 1,
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: AppMotion.fast,
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              borderRadius: AppRadii.large,
              border: Border.fromBorderSide(
                BorderSide(color: focused ? primary : AppPalette.outline, width: focused ? 4 : 1),
              ),
              boxShadow: [
                BoxShadow(
                  color: focused ? primary.withValues(alpha: 0.42) : const Color(0x66000000),
                  blurRadius: focused ? 32 : 12,
                  spreadRadius: focused ? 1 : 0,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Material(
              color: AppPalette.surface,
              clipBehavior: Clip.antiAlias,
              borderRadius: AppRadii.large,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Hero(
                    tag: 'anime-poster-${anime.id}',
                    child: AppNetworkImage(
                      imageUrl: posterUri.hasScheme ? posterUrl : null,
                      semanticLabel: anime.title,
                    ),
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
                          style: textTheme.titleMedium?.copyWith(
                            color: AppPalette.textPrimary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (focused)
                    Positioned(
                      top: AppSpacing.sm,
                      right: AppSpacing.sm,
                      child: DecoratedBox(
                        decoration: BoxDecoration(color: primary, shape: BoxShape.circle),
                        child: const Padding(
                          padding: EdgeInsets.all(AppSpacing.xs),
                          child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: 30),
                        ),
                      ),
                    ),
                  if (isFavorite ?? anime.isFavorite ?? false)
                    Positioned(
                      top: AppSpacing.sm,
                      left: AppSpacing.sm,
                      child: Tooltip(
                        message: 'В избранном',
                        child: DecoratedBox(
                          decoration: const BoxDecoration(color: Color(0xDD080B14), shape: BoxShape.circle),
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.xs),
                            child: Icon(
                              Icons.star_rounded,
                              key: ValueKey('favorite-${anime.id}'),
                              color: AppPalette.secondary,
                              size: 28,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
