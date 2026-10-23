import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';

import '../../../catalog/domain/models/catalog_filter.dart';
import '../../domain/models/anime_episode.dart';
import '../../domain/models/anime_part.dart';
import '../../domain/models/anime_screen_data.dart';
import 'anime_watch_order.dart';
import 'mobile_anime_poster_header.dart';
import 'mobile_episode_row.dart';

/// Touch composition shares data and actions with the TV route, but no TV focus graph.
class MobileAnimeContent extends StatefulWidget {
  const MobileAnimeContent({
    required this.data,
    required this.episodes,
    required this.watched,
    required this.onEpisodeTap,
    required this.onRetry,
    required this.onRefresh,
    required this.controller,
    this.playEpisode,
    this.fallbackPosterUri,
    this.onFilterTap,
    this.onPartTap,
    this.favoriteAction,
    this.filterActions,
    this.yearAction,
    this.rewatch = false,
    super.key,
  });

  final AnimeScreenData data;
  final List<AnimeEpisode> episodes;
  final Set<int> watched;
  final AnimeEpisode? playEpisode;
  final Uri? fallbackPosterUri;
  final Widget? favoriteAction;
  final Widget? filterActions;
  final Widget? yearAction;
  final ValueChanged<AnimeEpisode> onEpisodeTap;
  final ValueChanged<CatalogFilter>? onFilterTap;
  final ValueChanged<AnimePart>? onPartTap;
  final bool rewatch;
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
    final ratingLabel = details.rating?.toStringAsFixed(1).replaceAll('.', ',');
    final sectionStyle = AppContentTypography.sectionTitleOf(context);
    final mutedStyle = theme.bodyMedium?.copyWith(color: AppPalette.textSecondary);
    final wide = MediaQuery.sizeOf(context).width >= 600;
    final description = details.description?.trim();
    final hasDescription = description != null && description.isNotEmpty;
    final pinWatch = wide && MediaQuery.sizeOf(context).height < 500 && MediaQuery.textScalerOf(context).scale(14) > 21;
    final episode = widget.playEpisode;
    final watchAction = episode == null
        ? null
        : AppButton(
            onPressed: () => widget.onEpisodeTap(episode),
            icon: const AppIcon(AppIconType.play),
            label: widget.rewatch ? 'Посмотреть снова' : 'Смотреть серию ${episode.number}',
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
        Semantics(header: true, child: Text(details.title, style: AppContentTypography.detailTitleOf(context))),
        const SizedBox(height: AppSpacing.lg),
        MobileAnimePosterHeader(
          animeId: details.id,
          posterUri: details.posterUri ?? widget.fallbackPosterUri,
          fallbackPosterUri: widget.fallbackPosterUri,
          title: details.title,
          metadata: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (details.isOngoing) ...[
                Text('Онгоинг', style: theme.labelLarge?.copyWith(color: AppPalette.secondary)),
                const SizedBox(height: 8),
              ],
              if (ratingLabel case final rating?) ...[
                AppMetadataBadge(icon: Icons.grade_rounded, label: rating, semanticLabel: 'Рейтинг $rating из 10'),
                const SizedBox(height: AppSpacing.sm),
              ],
              if (widget.yearAction case final action?)
                action
              else if (details.year case final year?)
                Text(year, style: theme.bodyMedium),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (!pinWatch && watchAction != null) ...[
          watchAction,
          if (widget.favoriteAction != null) const SizedBox(height: 8),
        ],
        ?widget.favoriteAction,
        if (widget.filterActions case final actions?) ...[const SizedBox(height: 20), actions],
        if (hasDescription) ...[
          const SizedBox(height: 24),
          Semantics(header: true, child: Text('Сюжет', style: sectionStyle)),
          const SizedBox(height: 8),
          Text(
            description,
            maxLines: _expanded ? null : 4,
            overflow: _expanded ? TextOverflow.clip : TextOverflow.ellipsis,
            style: AppContentTypography.descriptionOf(context),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => setState(() => _expanded = !_expanded),
              child: Text(_expanded ? 'Свернуть описание' : 'Подробнее'),
            ),
          ),
        ],
        if (details.updateMessage case final message?) ...[
          const SizedBox(height: AppSpacing.lg),
          Text(message, style: theme.bodyLarge),
        ],
        if (details.publicationDate case final date?) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(date, style: mutedStyle),
        ],
        if (details.seriesInfo case final series?) ...[
          const SizedBox(height: AppSpacing.md),
          Text(series, style: theme.bodyMedium),
        ],
        if (details.voiceover case final voiceover?) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(voiceover, style: theme.bodyMedium),
        ],
        if (details.parts.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          AnimeWatchOrder(parts: details.parts, currentId: details.id, onSelected: widget.onPartTap),
        ],
        const SizedBox(height: 24),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Expanded(
              child: Semantics(header: true, child: Text('Серии', style: sectionStyle)),
            ),
            Text('В списке: ${widget.episodes.length}', style: mutedStyle),
          ],
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
