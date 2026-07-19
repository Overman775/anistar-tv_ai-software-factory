import 'package:flutter/material.dart';
import 'package:ui_kit/ui_kit.dart';

import '../../domain/models/anime_episode.dart';

class EpisodeCard extends StatelessWidget {
  const EpisodeCard({
    required this.episode,
    required this.onTap,
    super.key,
    this.autofocus = false,
    this.onFocusChanged,
  });

  final bool autofocus;
  final AnimeEpisode episode;
  final ValueChanged<bool>? onFocusChanged;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final preview = episode.previewUri;

    return TvFocusable(
      autofocus: autofocus,
      onFocusChanged: onFocusChanged,
      onPressed: onTap,
      semanticLabel: episode.title,
      builder: (context, focused) {
        final theme = Theme.of(context);
        final primary = theme.colorScheme.primary;
        final textTheme = theme.textTheme;

        return AnimatedScale(
          duration: AppMotion.fast,
          scale: focused ? 1.045 : 1,
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: AppMotion.fast,
            decoration: BoxDecoration(
              border: Border.fromBorderSide(
                BorderSide(color: focused ? primary : AppPalette.outline, width: focused ? 4 : 1),
              ),
              borderRadius: AppRadii.large,
              boxShadow: [
                BoxShadow(
                  blurRadius: focused ? 28 : 10,
                  color: focused ? primary.withValues(alpha: 0.4) : const Color(0x55000000),
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (preview != null)
                  AppNetworkImage(imageUrl: preview.toString(), semanticLabel: episode.title)
                else
                  const ColoredBox(
                    color: AppPalette.surfaceElevated,
                    child: Center(child: Icon(Icons.movie_outlined, size: 44, color: AppPalette.textSecondary)),
                  ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x22000000), Color(0xEE080B14)],
                    ),
                  ),
                ),
                Positioned(
                  top: AppSpacing.sm,
                  left: AppSpacing.sm,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0xD9080B14),
                      borderRadius: AppRadii.pill,
                      border: Border.fromBorderSide(
                        BorderSide(color: focused ? primary : AppPalette.outline, width: focused ? 2 : 1),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                      child: Text(
                        'СЕРИЯ ${episode.number}',
                        style: textTheme.labelMedium?.copyWith(
                          color: focused ? Colors.white : AppPalette.textSecondary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: AppSpacing.md,
                  right: AppSpacing.md,
                  bottom: AppSpacing.md,
                  child: Row(
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: focused ? primary : AppPalette.surfaceElevated.withValues(alpha: 0.88),
                          shape: BoxShape.circle,
                        ),
                        child: const Padding(
                          padding: EdgeInsets.all(AppSpacing.xs),
                          child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: 26),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          episode.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.titleMedium?.copyWith(
                            color: AppPalette.textPrimary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
