import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';

import '../../domain/models/anime_screen_data.dart';
import 'anime_description.dart';
import 'anime_layout.dart';
import 'anime_metadata_chip.dart';

class AnimeHero extends StatelessWidget {
  const AnimeHero({required this.data, super.key, this.onPlayFirstEpisode, this.favoriteAction});

  final AnimeScreenData data;
  final Widget? favoriteAction;
  final VoidCallback? onPlayFirstEpisode;

  @override
  Widget build(BuildContext context) {
    final details = data.details;
    final posterUri = details.posterUri;
    final posterUrl = posterUri?.toString();
    final metadata = [details.year, details.seriesInfo, details.voiceover].whereType<String>().join(' • ');
    final textTheme = Theme.of(context).textTheme;

    return LayoutBuilder(
      builder: (context, constraints) => SizedBox(
        height: AnimeLayout.heroHeight(constraints.maxWidth),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (posterUrl != null)
              Align(
                alignment: Alignment.centerRight,
                child: FractionallySizedBox(
                  widthFactor: 0.58,
                  heightFactor: 1,
                  child: Opacity(
                    opacity: 0.24,
                    child: AppNetworkImage(imageUrl: posterUrl, errorWidget: const SizedBox.shrink()),
                  ),
                ),
              ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerRight,
                  end: Alignment.centerLeft,
                  colors: [Color(0x18080B14), AppPalette.background],
                  stops: [0, 0.7],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.xxl, AppSpacing.lg, AppSpacing.xxl, AppSpacing.xl),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (posterUrl != null)
                    Hero(
                      tag: 'anime-poster-${details.id}',
                      child: AspectRatio(
                        aspectRatio: 2 / 3,
                        child: DecoratedBox(
                          decoration: const BoxDecoration(
                            borderRadius: AppRadii.large,
                            boxShadow: [BoxShadow(color: Color(0x99000000), blurRadius: 28, offset: Offset(0, 14))],
                          ),
                          child: ClipRRect(
                            borderRadius: AppRadii.large,
                            child: AppNetworkImage(
                              imageUrl: posterUrl,
                              borderRadius: AppRadii.large,
                              semanticLabel: details.title,
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (posterUrl != null) const SizedBox(width: AppSpacing.xl),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
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
                          style: (constraints.maxWidth >= 1200 ? textTheme.headlineLarge : textTheme.headlineMedium)
                              ?.copyWith(color: AppPalette.textPrimary),
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
                                autofocus: true,
                                onPressed: playAction,
                                icon: const Icon(Icons.play_arrow_rounded, size: 30),
                                label: Text('Смотреть серию ${data.episodes.first.number}'),
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
        ),
      ),
    );
  }
}
