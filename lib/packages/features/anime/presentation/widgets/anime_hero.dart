import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';

import '../../domain/models/anime_episode.dart';
import '../../domain/models/anime_screen_data.dart';
import 'anime_description.dart';
import 'anime_layout.dart';
import 'anime_metadata_chip.dart';

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
  });

  final AnimeScreenData data;
  final AnimeEpisode? playEpisode;
  final Widget? filterActions;
  final FocusNode? playFocusNode;
  final Widget? favoriteAction;
  final Uri? fallbackPosterUri;
  final VoidCallback? onPlayFirstEpisode;

  @override
  Widget build(BuildContext context) {
    final details = data.details;
    final posterUri = details.posterUri ?? fallbackPosterUri;
    final posterUrl = posterUri?.toString();
    final fallbackPosterUrl = fallbackPosterUri?.toString();
    final metadata = [details.year, details.seriesInfo, details.voiceover].whereType<String>().join(' • ');

    return LayoutBuilder(
      builder: (context, constraints) {
        final textScale = MediaQuery.textScalerOf(context).scale(18) / 18;
        final expandedText = textScale > 1;
        final height = AnimeLayout.heroHeight(constraints.maxWidth, textScale: textScale);
        final content = Stack(
          fit: expandedText ? StackFit.loose : StackFit.expand,
          children: [
            if (posterUrl != null)
              Positioned.fill(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: FractionallySizedBox(
                    widthFactor: 0.58,
                    heightFactor: 1,
                    child: Opacity(
                      opacity: 0.24,
                      child: AppNetworkImage(
                        imageUrl: posterUrl,
                        fallbackImageUrl: fallbackPosterUrl,
                        errorWidget: const SizedBox.shrink(),
                      ),
                    ),
                  ),
                ),
              ),
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerRight,
                    end: Alignment.centerLeft,
                    colors: [Color(0x18080B14), AppPalette.background],
                    stops: [0, 0.7],
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                constraints.maxWidth < 600 ? AppSpacing.md : AppSpacing.xxl,
                AppSpacing.lg,
                constraints.maxWidth < 600 ? AppSpacing.md : AppSpacing.xxl,
                AppSpacing.xl,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (posterUrl != null && constraints.maxWidth >= 600)
                    SizedBox(
                      height: expandedText
                          ? AnimeLayout.baseHeroHeight(constraints.maxWidth) - AppSpacing.lg - AppSpacing.xl
                          : null,
                      child: AspectRatio(
                        aspectRatio: 2 / 3,
                        child: DecoratedBox(
                          decoration: const BoxDecoration(
                            borderRadius: AppRadii.large,
                            boxShadow: [BoxShadow(color: Color(0x99000000), blurRadius: 28, offset: Offset(0, 14))],
                          ),
                          child: ClipRRect(
                            borderRadius: AppRadii.large,
                            child: TvPosterHero(
                              tag: 'anime-poster-${details.id}',
                              imageUrl: posterUrl,
                              fallbackImageUrl: fallbackPosterUrl,
                              semanticLabel: details.title,
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (posterUrl != null && constraints.maxWidth >= 600) const SizedBox(width: AppSpacing.xl),
                  Expanded(
                    child: Column(
                      mainAxisSize: expandedText ? MainAxisSize.min : MainAxisSize.max,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        filterActions ??
                            Wrap(
                              spacing: AppSpacing.sm,
                              runSpacing: AppSpacing.sm,
                              children: [
                                if (details.isOngoing)
                                  const AnimeMetadataChip(icon: Icons.sensors_rounded, label: 'ОНГОИНГ'),
                                for (final genre in details.genres.take(3)) AnimeMetadataChip(label: genre),
                              ],
                            ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          details.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppContentTypography.detailTitleOf(
                            context,
                            wide: constraints.maxWidth >= 1200,
                          )?.copyWith(color: AppPalette.textPrimary),
                        ),
                        if (metadata.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            metadata,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: AppPalette.secondary, fontWeight: FontWeight.w700),
                          ),
                        ],
                        const SizedBox(height: AppSpacing.md),
                        if (expandedText)
                          AnimeDescription(description: details.description ?? 'Описание пока недоступно.')
                        else
                          Expanded(
                            child: AnimeDescription(description: details.description ?? 'Описание пока недоступно.'),
                          ),
                        const SizedBox(height: AppSpacing.md),
                        Wrap(
                          spacing: AppSpacing.md,
                          runSpacing: AppSpacing.sm,
                          children: [
                            if (onPlayFirstEpisode case final playAction?)
                              FilledButton.icon(
                                focusNode: playFocusNode,
                                autofocus: true,
                                onPressed: playAction,
                                icon: const Icon(Icons.play_arrow_rounded, size: 30),
                                label: Text('Смотреть серию ${playEpisode?.number ?? data.episodes.first.number}'),
                              ),
                            ?favoriteAction,
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        );

        return expandedText
            ? ConstrainedBox(
                constraints: BoxConstraints(minHeight: height),
                child: content,
              )
            : SizedBox(height: height, child: content);
      },
    );
  }
}
