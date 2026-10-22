import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';

import '../../domain/models/anime_episode.dart';
import '../../domain/models/anime_screen_data.dart';
import 'anime_description.dart';

class AnimeHero extends StatelessWidget {
  const AnimeHero({
    required this.data,
    super.key,
    this.onPlayFirstEpisode,
    this.playEpisode,
    this.favoriteAction,
    this.fallbackPosterUri,
    this.playFocusNode,
    this.filterActions,
    this.rewatch = false,
  });

  final AnimeScreenData data;
  final AnimeEpisode? playEpisode;
  final Widget? filterActions;
  final FocusNode? playFocusNode;
  final Widget? favoriteAction;
  final Uri? fallbackPosterUri;
  final VoidCallback? onPlayFirstEpisode;
  final bool rewatch;

  @override
  Widget build(BuildContext context) {
    final details = data.details;
    final theme = Theme.of(context).textTheme;
    final posterUri = details.posterUri ?? fallbackPosterUri;
    final episode = playEpisode;
    final watchLabel = episode == null ? 'Нет доступных серий' : 'Смотреть серию ${episode.number}';
    final metadata = [details.year, ...details.genres].whereType<String>().join(' · ');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl, vertical: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(header: true, child: Text(details.title, style: AppContentTypography.detailTitleOf(context))),
          const SizedBox(height: AppSpacing.lg),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: (MediaQuery.sizeOf(context).width * 0.22).clamp(140.0, 240.0),
                child: AspectRatio(
                  aspectRatio: AppSizes.posterRatio,
                  child: TvPosterHero(
                    tag: 'anime-poster-${details.id}',
                    imageUrl: posterUri?.toString(),
                    fallbackImageUrl: fallbackPosterUri?.toString(),
                    semanticLabel: details.title,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xl),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (details.rating case final rating?) ...[
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const AppIcon(AppIconType.star, size: 20),
                          const SizedBox(width: 8),
                          Text(rating.toStringAsFixed(1).replaceAll('.', ','), style: theme.titleMedium),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],
                    if (metadata.isNotEmpty) Text(metadata, style: theme.bodyLarge),
                    if (details.director case final director?) Text(director, style: theme.bodyMedium),
                    if (details.isOngoing) Text('Онгоинг', style: theme.labelLarge),
                    if (filterActions case final filters?) ...[const SizedBox(height: AppSpacing.lg), filters],
                    const SizedBox(height: AppSpacing.lg),
                    Wrap(
                      spacing: AppSpacing.md,
                      runSpacing: AppSpacing.sm,
                      children: [
                        AppButton(
                          focusNode: playFocusNode,
                          autofocus: episode != null,
                          enabled: episode != null,
                          onPressed: () => onPlayFirstEpisode?.call(),
                          icon: const AppIcon(AppIconType.play),
                          label: rewatch ? 'Посмотреть снова' : watchLabel,
                        ),
                        ?favoriteAction,
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          if (details.description case final description?) ...[
            Text('Сюжет', style: AppContentTypography.sectionTitleOf(context)),
            const SizedBox(height: AppSpacing.md),
            AnimeDescription(description: description),
          ],
          if (details.updateMessage case final message?) ...[
            const SizedBox(height: AppSpacing.lg),
            Text(message, style: theme.bodyLarge),
          ],
          if (details.publicationDate case final date?) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(date, style: theme.bodyMedium?.copyWith(color: AppPalette.textSecondary)),
          ],
          if (details.seriesInfo case final series?) ...[
            const SizedBox(height: AppSpacing.lg),
            Text(series, style: theme.bodyMedium),
          ],
          if (details.voiceover case final voiceover?) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(voiceover, style: theme.bodyMedium),
          ],
        ],
      ),
    );
  }
}
