import 'dart:async';

import 'package:app_logging/app_logging.dart';
import 'package:app_logging/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';

import '../../../favorites/favorites_providers.dart';
import '../../../favorites/presentation/favorite_button.dart';
import '../../../watch_history/watched_episodes.dart';
import '../../anime_providers.dart';
import '../../domain/models/anime_episode.dart';
import '../../domain/models/anime_screen_data.dart';
import '../widgets/anime_hero.dart';
import '../widgets/anime_layout.dart';
import '../widgets/anime_skeleton.dart';
import '../widgets/episode_card.dart';

class AnimeScreen extends ConsumerStatefulWidget {
  const AnimeScreen({
    required this.animeId,
    required this.slug,
    required this.fallbackTitle,
    required this.onEpisodeTap,
    super.key,
  });

  final int animeId;
  final String fallbackTitle;
  final ValueChanged<AnimeEpisode> onEpisodeTap;
  final String slug;

  @override
  ConsumerState<AnimeScreen> createState() => _AnimeScreenState();
}

class _AnimeScreenState extends ConsumerState<AnimeScreen> {
  final ScrollController _scrollController = ScrollController();
  late Future<AnimeScreenData> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Widget _buildFuture(BuildContext context, AsyncSnapshot<AnimeScreenData> snapshot) {
    if (snapshot.connectionState != ConnectionState.done) {
      return const AnimeSkeleton();
    }
    if (snapshot.hasError) {
      return TvStateView(
        icon: Icons.cloud_off_rounded,
        title: 'Не удалось загрузить аниме',
        message: snapshot.error?.toString() ?? 'Неизвестная ошибка',
        actionLabel: 'Повторить',
        onAction: _retry,
      );
    }
    final data = snapshot.requireData;
    final episodes = data.episodes;

    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        SliverToBoxAdapter(
          child: AnimeHero(
            data: data,
            favoriteAction: FavoriteButton(
              animeId: data.details.id,
              slug: data.details.slug,
              title: data.details.title,
              initialFavorite: data.details.isFavorite,
            ),
            onPlayFirstEpisode: episodes.isEmpty ? null : () => _openEpisode(episodes.first),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.xxl, AppSpacing.lg, AppSpacing.xxl, AppSpacing.sm),
          sliver: SliverToBoxAdapter(
            child: TvSectionHeader(
              title: 'Серии',
              trailing: Text(
                '${episodes.length}',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppPalette.textSecondary),
              ),
            ),
          ),
        ),
        if (episodes.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: TvStateView(
              icon: Icons.playlist_remove_rounded,
              title: 'Серии не найдены',
              message: 'Для этого аниме пока нет доступных выпусков.',
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.xxl, AppSpacing.sm, AppSpacing.xxl, 72),
            sliver: SliverLayoutBuilder(
              builder: (context, constraints) => SliverGrid.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: AnimeLayout.episodeColumns(constraints.crossAxisExtent),
                  mainAxisSpacing: AppSpacing.xl,
                  crossAxisSpacing: AppSpacing.lg,
                  childAspectRatio: 16 / 9,
                ),
                itemCount: episodes.length,
                itemBuilder: (context, index) {
                  final episode = episodes[index];

                  return Builder(
                    builder: (episodeContext) => EpisodeCard(
                      episode: episode,
                      isWatched:
                          ref.watch(watchedEpisodesProvider(widget.animeId)).value?.contains(episode.number) ?? false,
                      onFocusChanged: (focused) => _onEpisodeFocusChanged(episodeContext, focused),
                      onTap: () => _openEpisode(episode),
                    ),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }

  void _load() {
    final logger = ref.read(loggerProvider);
    final revision = ref.read(favoritesControllerProvider).revision;
    _future = ref
        .read(animeRepositoryProvider)
        .getAnime(id: widget.animeId, slug: widget.slug)
        .then(
          (result) => result.when(
            failure: (failure) {
              throw failure;
            },
            success: (data) {
              if (mounted && ref.read(favoritesControllerProvider).revision == revision) {
                ref.read(favoritesControllerProvider.notifier).observe(data.details.id, data.details.isFavorite);
              }
              logger.infoFor<AnimeScreen>('Anime loaded: ${data.episodes.length} episodes');

              return data;
            },
          ),
        );
  }

  void _openEpisode(AnimeEpisode episode) => widget.onEpisodeTap(episode);

  void _onEpisodeFocusChanged(BuildContext episodeContext, bool focused) {
    if (!focused) {
      return;
    }
    unawaited(
      Scrollable.ensureVisible(
        episodeContext,
        alignment: 0.58,
        duration: AppMotion.standard,
        curve: Curves.easeOutCubic,
      ),
    );
  }

  void _retry() {
    ref.read(loggerProvider).infoFor<AnimeScreen>('Retrying anime ${widget.animeId} loading');
    setState(_load);
  }

  @override
  void didUpdateWidget(covariant AnimeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animeId != widget.animeId || oldWidget.slug != widget.slug) {
      _load();
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      toolbarHeight: 80,
      titleSpacing: AppSpacing.lg,
      title: Text(widget.fallbackTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
    ),
    body: TvBackdrop(
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        child: FutureBuilder<AnimeScreenData>(future: _future, builder: _buildFuture),
      ),
    ),
  );
}
