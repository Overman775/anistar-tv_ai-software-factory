import 'dart:async';

import 'package:app_logging/app_logging.dart';
import 'package:app_logging/providers.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';

import '../../../catalog/domain/models/catalog_filter.dart';
import '../../../favorites/favorites_providers.dart';
import '../../../favorites/presentation/favorite_button.dart';
import '../../../watch_history/watched_episodes.dart';
import '../../anime_providers.dart';
import '../../domain/models/anime_episode.dart';
import '../../domain/models/anime_screen_data.dart';
import '../widgets/anime_filter_row.dart';
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
    this.fallbackPosterUri,
    this.onFilterTap,
    super.key,
  });

  final int animeId;
  final ValueChanged<CatalogFilter>? onFilterTap;
  final String fallbackTitle;
  final Uri? fallbackPosterUri;
  final ValueChanged<AnimeEpisode> onEpisodeTap;
  final String slug;

  @override
  ConsumerState<AnimeScreen> createState() => _AnimeScreenState();
}

class _AnimeScreenState extends ConsumerState<AnimeScreen> {
  final ScrollController _scrollController = ScrollController();
  final _backFocus = FocusNode(debugLabel: 'Назад к каталогу');
  final _playFocus = FocusNode(debugLabel: 'Смотреть первую серию');
  final _favoriteFocus = FocusNode(debugLabel: 'Избранное сериала');
  final Map<int, FocusNode> _episodeFocus = {};
  List<int> _episodeNumbers = [];
  final Map<String, FocusNode> _filterFocus = {};
  List<CatalogFilter> _filters = [];
  int _lastFilterIndex = 0;
  int _episodeColumns = 2;
  late Future<AnimeScreenData> _future;
  Animation<double>? _routeAnimation;
  bool _entered = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Widget _buildFuture(BuildContext context, AsyncSnapshot<AnimeScreenData> snapshot) {
    if (!_entered || snapshot.connectionState != ConnectionState.done) {
      return AnimeSkeleton(animeId: widget.animeId, posterUri: widget.fallbackPosterUri, title: widget.fallbackTitle);
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
    _filters = widget.onFilterTap == null ? [] : data.details.filters;
    final watched = ref.watch(watchedEpisodesProvider(widget.animeId)).value ?? const <int>{};
    final ascending = data.episodes.toList()..sort((a, b) => a.number.compareTo(b.number));
    final playEpisode =
        ascending.where((episode) => !episode.isWatched && !watched.contains(episode.number)).firstOrNull ??
        ascending.firstOrNull;
    final episodes = ascending.reversed.toList();
    _episodeNumbers = episodes.map((episode) => episode.number).toList(growable: false);

    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        SliverToBoxAdapter(
          child: AnimeHero(
            playFocusNode: _playFocus,
            data: data,
            filterActions: _filters.isEmpty
                ? null
                : AnimeFilterRow(
                    filters: _filters,
                    focusNodes: _filterFocus,
                    onSelected: (filter) => widget.onFilterTap?.call(filter),
                    onFocused: (index) => _lastFilterIndex = index,
                  ),
            fallbackPosterUri: widget.fallbackPosterUri,
            favoriteAction: FavoriteButton(
              focusNode: _favoriteFocus,
              autofocus: episodes.isEmpty,
              animeId: data.details.id,
              slug: data.details.slug,
              title: data.details.title,
              initialFavorite: data.details.isFavorite,
            ),
            playEpisode: playEpisode,
            onPlayFirstEpisode: playEpisode == null ? null : () => _openEpisode(playEpisode),
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
              builder: (context, constraints) {
                _episodeColumns = AnimeLayout.episodeColumns(constraints.crossAxisExtent);

                return SliverGrid.builder(
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
                        focusNode: _episodeFocus.putIfAbsent(
                          episode.number,
                          () => FocusNode(debugLabel: episode.title),
                        ),
                        episode: episode,
                        isWatched:
                            ref.watch(watchedEpisodesProvider(widget.animeId)).value?.contains(episode.number) ?? false,
                        onFocusChanged: (focused) => _onEpisodeFocusChanged(episodeContext, focused),
                        onTap: () => _openEpisode(episode),
                      ),
                    );
                  },
                );
              },
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

  KeyEventResult _handleNavigation(FocusNode node, KeyEvent event) {
    final current = FocusManager.instance.primaryFocus;
    final key = event.logicalKey;
    FocusNode? target;
    final firstAction = _episodeNumbers.isEmpty ? _favoriteFocus : _playFocus;
    final filterIndex = _filters.indexWhere((filter) => _filterFocus[filter.path] == current);
    final index = _episodeNumbers.indexWhere((number) => identical(_episodeFocus[number], current));
    if (key == LogicalKeyboardKey.arrowUp && (current == _playFocus || current == _favoriteFocus)) {
      target = _backFocus.context == null ? null : _backFocus;
      if (_filters.isNotEmpty) {
        target = _filterFocus[_filters[_lastFilterIndex.clamp(0, _filters.length - 1)].path];
      }
    } else if (key == LogicalKeyboardKey.arrowDown && current == _backFocus) {
      target = _filters.isEmpty
          ? firstAction
          : _filterFocus[_filters[_lastFilterIndex.clamp(0, _filters.length - 1)].path];
    } else if (filterIndex >= 0 && key == LogicalKeyboardKey.arrowDown) {
      target = firstAction;
    } else if (filterIndex >= 0 && key == LogicalKeyboardKey.arrowUp) {
      target = _backFocus.context == null ? current : _backFocus;
    } else if (filterIndex >= 0 && (key == LogicalKeyboardKey.arrowLeft || key == LogicalKeyboardKey.arrowRight)) {
      final next = (filterIndex + (key == LogicalKeyboardKey.arrowRight ? 1 : -1)).clamp(0, _filters.length - 1);
      target = _filterFocus[_filters[next].path];
    } else if (key == LogicalKeyboardKey.arrowDown &&
        (current == _playFocus || current == _favoriteFocus) &&
        _episodeNumbers.isNotEmpty) {
      target = _episodeFocus[_episodeNumbers.first];
    } else if (key == LogicalKeyboardKey.arrowUp && index >= 0 && index < _episodeColumns) {
      target = firstAction;
    } else if (key == LogicalKeyboardKey.arrowRight && current == _playFocus) {
      target = _favoriteFocus;
    } else if (key == LogicalKeyboardKey.arrowLeft && current == _favoriteFocus) {
      target = firstAction;
    }
    if (target?.canRequestFocus != true || target?.context == null) {
      return KeyEventResult.ignored;
    }
    if (event is KeyDownEvent || event is KeyRepeatEvent) {
      target?.requestFocus();
      if (target == _playFocus || target == _favoriteFocus) {
        unawaited(
          _scrollController.animateTo(
            0,
            duration: AppMotion.durationOf(context, AppMotion.fast),
            curve: AppMotion.enterCurve,
          ),
        );
      }
    }

    return KeyEventResult.handled;
  }

  void _onEpisodeFocusChanged(BuildContext episodeContext, bool focused) {
    if (!focused) {
      return;
    }
    unawaited(
      Scrollable.ensureVisible(
        episodeContext,
        alignment: 0.58,
        duration: AppMotion.durationOf(context, AppMotion.standard),
        curve: AppMotion.enterCurve,
      ),
    );
  }

  void _retry() {
    ref.read(loggerProvider).infoFor<AnimeScreen>('Retrying anime ${widget.animeId} loading');
    setState(_load);
  }

  void _onRouteStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && mounted && !_entered && ModalRoute.of(context)?.offstage != true) {
      setState(() => _entered = true);
    }
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
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    final animation = route?.animation;
    if (!identical(animation, _routeAnimation)) {
      _routeAnimation?.removeStatusListener(_onRouteStatus);
      _routeAnimation = animation;
      animation?.addStatusListener(_onRouteStatus);
    }
    // HeroController temporarily lays out the destination offstage with a
    // completed proxy animation. That is not the end of the actual flight.
    if (animation == null ||
        AppMotion.reducedOf(context) ||
        route?.offstage != true && animation.status == AnimationStatus.completed) {
      _entered = true;
    }
  }

  @override
  void dispose() {
    _routeAnimation?.removeStatusListener(_onRouteStatus);
    _scrollController.dispose();
    _backFocus.dispose();
    _playFocus.dispose();
    _favoriteFocus.dispose();
    for (final focus in _filterFocus.values) {
      focus.dispose();
    }
    for (final focus in _episodeFocus.values) {
      focus.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Focus(
    canRequestFocus: false,
    onKeyEvent: _handleNavigation,
    child: TvBackdrop(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          leading: ModalRoute.of(context)?.canPop == true
              ? IconButton(
                  focusNode: _backFocus,
                  tooltip: 'Назад к каталогу',
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.arrow_back),
                )
              : null,
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          flexibleSpace: const TvHeaderSurface(),
          toolbarHeight: 80,
          titleSpacing: AppSpacing.lg,
          title: Text(widget.fallbackTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        body: SafeArea(
          top: false,
          minimum: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          child: FutureBuilder<AnimeScreenData>(future: _future, builder: _buildFuture),
        ),
      ),
    ),
  );
}
