import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ui_kit/ui_kit.dart';

import '../../domain/models/anime_episode.dart';
import '../../domain/models/anime_screen_data.dart';
import '../../domain/repositories/anime_repository.dart';
import '../widgets/anime_hero.dart';
import '../widgets/episode_card.dart';

class AnimeScreen extends StatefulWidget {
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
  State<AnimeScreen> createState() => _AnimeScreenState();
}

class _AnimeScreenState extends State<AnimeScreen> {
  final ScrollController _scrollController = ScrollController();
  late Future<AnimeScreenData> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Widget _buildFuture(BuildContext context, AsyncSnapshot<AnimeScreenData> snapshot) {
    if (snapshot.connectionState != ConnectionState.done) {
      return const TvProgressView(label: 'Загружаем аниме и серии…');
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
      clipBehavior: Clip.none,
      slivers: [
        SliverToBoxAdapter(
          child: AnimeHero(
            data: data,
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
                  crossAxisCount: _columnCount(constraints.crossAxisExtent),
                  mainAxisSpacing: AppSpacing.xl,
                  crossAxisSpacing: AppSpacing.lg,
                  childAspectRatio: 16 / 9,
                ),
                itemCount: episodes.length,
                itemBuilder: (context, index) {
                  final episode = episodes[index];

                  return EpisodeCard(
                    episode: episode,
                    onFocusChanged: (focused) => _onEpisodeFocusChanged(context, focused),
                    onTap: () => _openEpisode(episode),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }

  int _columnCount(double width) {
    if (width >= 1600) return 4;
    if (width >= 900) return 3;

    return 2;
  }

  void _load() {
    _future = context
        .read<AnimeRepository>()
        .getAnime(id: widget.animeId, slug: widget.slug)
        .then((result) => result.fold(onLeft: (failure) => throw failure, onRight: (data) => data));
  }

  void _openEpisode(AnimeEpisode episode) => widget.onEpisodeTap(episode);

  void _onEpisodeFocusChanged(BuildContext episodeContext, bool focused) {
    if (!focused) return;
    unawaited(
      Scrollable.ensureVisible(
        episodeContext,
        alignment: 0.58,
        alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
        duration: AppMotion.standard,
        curve: Curves.easeOutCubic,
      ),
    );
  }

  void _retry() {
    setState(_load);
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
