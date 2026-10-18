import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';

import '../../../catalog/domain/models/catalog_filter.dart';
import '../../domain/models/anime_episode.dart';
import '../../domain/models/anime_screen_data.dart';
import 'mobile_anime_poster_header.dart';
import 'mobile_episode_row.dart';

/// Touch composition shares data and actions with the TV route, but no TV focus graph.
class MobileAnimeContent extends StatefulWidget {
  const MobileAnimeContent({
    required this.data,
    required this.episodes,
    required this.watched,
    required this.favoriteAction,
    required this.onEpisodeTap,
    required this.onRetry,
    required this.onRefresh,
    required this.controller,
    this.playEpisode,
    this.fallbackPosterUri,
    this.onFilterTap,
    super.key,
  });

  final AnimeScreenData data;
  final List<AnimeEpisode> episodes;
  final Set<int> watched;
  final AnimeEpisode? playEpisode;
  final Uri? fallbackPosterUri;
  final Widget favoriteAction;
  final ValueChanged<AnimeEpisode> onEpisodeTap;
  final ValueChanged<CatalogFilter>? onFilterTap;
  final VoidCallback onRetry;
  final Future<void> Function() onRefresh;
  final ScrollController controller;

  @override
  State<MobileAnimeContent> createState() => _MobileAnimeContentState();
}

class _MobileAnimeContentState extends State<MobileAnimeContent> {
  bool _expanded = false;

  @override
  void didUpdateWidget(covariant MobileAnimeContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data.details.id != widget.data.details.id) {
      _expanded = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final details = widget.data.details;
    final theme = Theme.of(context).textTheme;
    final wide = MediaQuery.sizeOf(context).width >= 600;
    final metadata = [details.year, details.seriesInfo, details.voiceover].whereType<String>().join('\n');
    final description = details.description?.trim();
    final hasDescription = description != null && description.isNotEmpty;
    final pinWatch = wide && MediaQuery.sizeOf(context).height < 500 && MediaQuery.textScalerOf(context).scale(14) > 21;
    final episode = widget.playEpisode;
    final watchAction = episode == null
        ? null
        : FilledButton.icon(
            onPressed: () => widget.onEpisodeTap(episode),
            icon: const Icon(Icons.play_arrow_rounded),
            label: Text('Смотреть серию ${episode.number}', textAlign: TextAlign.center),
          );
    final list = ListView(
      controller: widget.controller,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        AppLayoutScope.horizontalPaddingOf(context),
        12,
        AppLayoutScope.horizontalPaddingOf(context),
        32,
      ),
      children: [
        MobileAnimePosterHeader(
          animeId: details.id,
          posterUri: details.posterUri ?? widget.fallbackPosterUri,
          fallbackPosterUri: widget.fallbackPosterUri,
          title: details.title,
          metadata: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (wide) ...[
                Semantics(header: true, child: Text(details.title, style: AppContentTypography.detailTitleOf(context))),
                const SizedBox(height: 12),
              ],
              if (details.isOngoing) ...[
                Text('Онгоинг', style: theme.labelLarge?.copyWith(color: AppPalette.secondary)),
                const SizedBox(height: 8),
              ],
              if (metadata.isNotEmpty) Text(metadata, style: theme.bodyMedium),
            ],
          ),
        ),
        if (!wide) ...[
          const SizedBox(height: 20),
          Semantics(header: true, child: Text(details.title, style: AppContentTypography.detailTitleOf(context))),
        ],
        const SizedBox(height: 16),
        if (!pinWatch && watchAction != null) ...[watchAction, const SizedBox(height: 8)],
        widget.favoriteAction,
        if (details.filters.isNotEmpty && widget.onFilterTap != null) ...[
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final filter in details.filters)
                ActionChip(label: Text(filter.label), onPressed: () => widget.onFilterTap?.call(filter)),
            ],
          ),
        ] else if (details.genres.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(details.genres.join(' • '), style: theme.bodyMedium?.copyWith(color: AppPalette.textSecondary)),
        ],
        const SizedBox(height: 24),
        Semantics(header: true, child: Text('О сериале', style: AppContentTypography.sectionTitleOf(context))),
        const SizedBox(height: 8),
        Text(
          hasDescription ? description : 'Описание пока недоступно.',
          maxLines: _expanded ? null : 4,
          overflow: _expanded ? TextOverflow.clip : TextOverflow.ellipsis,
          style: AppContentTypography.descriptionOf(context),
        ),
        if (hasDescription)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => setState(() => _expanded = !_expanded),
              child: Text(_expanded ? 'Свернуть описание' : 'Подробнее'),
            ),
          ),
        const SizedBox(height: 24),
        Semantics(
          header: true,
          child: Text('Серии · ${widget.episodes.length}', style: AppContentTypography.sectionTitleOf(context)),
        ),
        const SizedBox(height: 12),
        if (widget.episodes.isEmpty) ...[
          const Text('Серии не найдены. Для этого аниме пока нет доступных выпусков.'),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: widget.onRetry, child: const Text('Обновить серии')),
        ] else
          for (final episode in widget.episodes) ...[
            MobileEpisodeRow(
              key: ValueKey('mobile-episode-${episode.number}'),
              episode: episode,
              isWatched: episode.isWatched || widget.watched.contains(episode.number),
              onTap: () => widget.onEpisodeTap(episode),
            ),
            const Divider(height: 1),
          ],
      ],
    );
    final content = RefreshIndicator(
      key: const ValueKey('mobile-anime-refresh'),
      onRefresh: widget.onRefresh,
      child: list,
    );
    if (!pinWatch || watchAction == null) {
      return content;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: content),
        Padding(
          padding: EdgeInsets.fromLTRB(
            AppLayoutScope.horizontalPaddingOf(context),
            8,
            AppLayoutScope.horizontalPaddingOf(context),
            8,
          ),
          child: watchAction,
        ),
      ],
    );
  }
}
