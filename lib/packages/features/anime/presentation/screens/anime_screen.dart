import 'dart:async';

import 'package:app_logging/app_logging.dart';
import 'package:app_logging/providers.dart';
import 'package:core/data.dart';
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
import '../widgets/mobile_anime_content.dart';
import '../widgets/mobile_anime_skeleton.dart';

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
  int _episodeColumns = 3;
  double _episodeHeight = 0;
  int? _focusedEpisodeNumber;
  int _episodeNavigationGeneration = 0;
  late Future<AnimeScreenData> _future;
  Animation<double>? _routeAnimation;
  bool _entered = false;
  int _loadGeneration = 0;
  Future<void>? _mobileRefresh;
  final _disposed = Completer<void>();

  @override
  void initState() {
    super.initState();
    _playFocus.addListener(_revealFocusedAction);
    _favoriteFocus.addListener(_revealFocusedAction);
    _load();
  }

  void _revealFocusedAction() {
    if (!mounted || MediaQuery.textScalerOf(context).scale(18) <= 18) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final action = _playFocus.hasFocus ? _playFocus : _favoriteFocus;
      final actionContext = action.hasFocus ? action.context : null;
      if (actionContext != null) {
        unawaited(
          Scrollable.ensureVisible(
            actionContext,
            alignment: 0.5,
            duration: AppMotion.durationOf(context, AppMotion.fast),
            curve: AppMotion.enterCurve,
          ),
        );
      }
    });
  }

  Widget _buildFuture(BuildContext context, AsyncSnapshot<AnimeScreenData> snapshot) {
    final retainingMobileContent = !AppLayoutScope.isTvOf(context) && snapshot.data?.details.id == widget.animeId;
    if (!_entered || snapshot.connectionState != ConnectionState.done && !retainingMobileContent) {
      return AppLayoutScope.isTvOf(context)
          ? AnimeSkeleton(animeId: widget.animeId, posterUri: widget.fallbackPosterUri, title: widget.fallbackTitle)
          : MobileAnimeSkeleton(
              animeId: widget.animeId,
              posterUri: widget.fallbackPosterUri,
              title: widget.fallbackTitle,
            );
    }
    final error = snapshot.error;
    if (error != null) {
      final errorView = TvStateView(
        icon: Icons.cloud_off_rounded,
        title: 'Не удалось загрузить аниме',
        message: error is Failure ? error.message : 'Не удалось загрузить данные аниме. Повторите попытку.',
        actionLabel: 'Повторить',
        onAction: _retry,
      );
      if (AppLayoutScope.isTvOf(context)) {
        return errorView;
      }

      return RefreshIndicator(
        onRefresh: _refreshMobile,
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: SizedBox(height: constraints.maxHeight, child: errorView),
          ),
        ),
      );
    }
    final data = snapshot.requireData;
    final animeId = data.details.id;
    _filters = widget.onFilterTap == null ? [] : data.details.filters;
    final watched = ref.watch(watchedEpisodesProvider(widget.animeId)).value ?? const <int>{};
    final ascending = data.episodes.toList()..sort((a, b) => a.number.compareTo(b.number));
    final playEpisode =
        ascending.where((episode) => !episode.isWatched && !watched.contains(episode.number)).firstOrNull ??
        ascending.firstOrNull;
    final episodes = ascending.reversed.toList();
    _episodeNumbers = episodes.map((episode) => episode.number).toList(growable: false);
    if (_focusedEpisodeNumber != null && !_episodeNumbers.contains(_focusedEpisodeNumber)) {
      _focusedEpisodeNumber = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && ModalRoute.of(context)?.isCurrent != false) {
          final firstEpisode = _episodeNumbers.firstOrNull;
          final target = firstEpisode == null ? _favoriteFocus : _episodeFocus[firstEpisode];
          (target?.context == null ? _favoriteFocus : target)?.requestFocus();
        }
      });
    }

    if (!AppLayoutScope.isTvOf(context)) {
      return MobileAnimeContent(
        key: ValueKey(animeId),
        data: data,
        episodes: episodes,
        watched: watched,
        playEpisode: playEpisode,
        fallbackPosterUri: widget.fallbackPosterUri,
        controller: _scrollController,
        onEpisodeTap: _openEpisode,
        onRetry: _retry,
        onRefresh: _refreshMobile,
        onFilterTap: widget.onFilterTap,
        favoriteAction: FavoriteButton(
          animeId: animeId,
          slug: data.details.slug,
          title: data.details.title,
          initialFavorite: data.details.isFavorite,
        ),
      );
    }

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
              animeId: animeId,
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
          SliverToBoxAdapter(
            child: TvStateView(
              icon: Icons.playlist_remove_rounded,
              title: 'Серии не найдены',
              message: 'Для этого аниме пока нет доступных выпусков.',
              actionLabel: 'Обновить серии',
              onAction: _retry,
              autofocusAction: false,
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.xxl, AppSpacing.sm, AppSpacing.xxl, 72),
            sliver: SliverLayoutBuilder(
              builder: (context, constraints) {
                _episodeColumns = AnimeLayout.episodeColumns(constraints.crossAxisExtent);
                _episodeHeight = AnimeLayout.episodeHeight(context, constraints.crossAxisExtent);

                return SliverGrid.builder(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: AnimeLayout.episodeColumns(constraints.crossAxisExtent),
                    mainAxisSpacing: AppSpacing.xl,
                    crossAxisSpacing: AppSpacing.lg,
                    mainAxisExtent: _episodeHeight,
                  ),
                  itemCount: episodes.length,
                  findChildIndexCallback: _episodeIndexForKey,
                  itemBuilder: (context, index) {
                    final episode = episodes[index];

                    return Builder(
                      key: ValueKey(episode.number),
                      builder: (episodeContext) => EpisodeCard(
                        focusNode: _episodeFocus.putIfAbsent(
                          episode.number,
                          () => FocusNode(debugLabel: episode.title),
                        ),
                        episode: episode,
                        isWatched:
                            ref.watch(watchedEpisodesProvider(widget.animeId)).value?.contains(episode.number) ?? false,
                        onFocusChanged: (focused) => _onEpisodeFocusChanged(episodeContext, episode.number, focused),
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
    _future = _fetchData(++_loadGeneration);
  }

  Future<AnimeScreenData> _fetchData(int generation) {
    final logger = ref.read(loggerProvider);
    final revision = ref.read(favoritesControllerProvider).revision;

    return ref
        .read(animeRepositoryProvider)
        .getAnime(id: widget.animeId, slug: widget.slug)
        .then(
          (result) => result.when(
            failure: (failure) {
              throw failure;
            },
            success: (data) {
              if (mounted &&
                  generation == _loadGeneration &&
                  ref.read(favoritesControllerProvider).revision == revision) {
                ref.read(favoritesControllerProvider.notifier).observe(data.details.id, data.details.isFavorite);
              }
              logger.infoFor<AnimeScreen>('Anime loaded: ${data.episodes.length} episodes');

              return data;
            },
          ),
        );
  }

  Future<void> _refreshMobile() => _mobileRefresh ??= _performMobileRefresh().whenComplete(() => _mobileRefresh = null);

  Future<void> _performMobileRefresh() async {
    final generation = ++_loadGeneration;
    try {
      final data = await Future.any<AnimeScreenData?>([
        _fetchData(generation),
        _disposed.future.then<AnimeScreenData?>((_) => null),
      ]);
      if (mounted && generation == _loadGeneration && data != null) {
        setState(() {
          _future = Future.value(data);
        });
      }
    } on Object catch (error) {
      if (mounted && generation == _loadGeneration) {
        final message = error is Failure ? error.message : 'Проверьте подключение и повторите жест.';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Не удалось обновить аниме. $message')));
      }
    }
  }

  void _openEpisode(AnimeEpisode episode) => widget.onEpisodeTap(episode);

  int? _episodeIndexForKey(Key key) {
    final index = key is ValueKey<int> ? _episodeNumbers.indexOf(key.value) : -1;

    return index < 0 ? null : index;
  }

  int _episodeBelow(int index) {
    if (index ~/ _episodeColumns == (_episodeNumbers.length - 1) ~/ _episodeColumns) {
      return index;
    }

    return (index + _episodeColumns).clamp(0, _episodeNumbers.length - 1);
  }

  KeyEventResult _handleNavigation(FocusNode node, KeyEvent event) {
    final current = FocusManager.instance.primaryFocus;
    final key = event.logicalKey;
    FocusNode? target;
    final firstAction = _episodeNumbers.isEmpty ? _favoriteFocus : _playFocus;
    final filterIndex = _filters.indexWhere((filter) => _filterFocus[filter.path] == current);
    final index = _episodeNumbers.indexWhere((number) => identical(_episodeFocus[number], current));
    if (index >= 0 && !(key == LogicalKeyboardKey.arrowUp && index < _episodeColumns)) {
      final column = index % _episodeColumns;
      final next = switch (key) {
        LogicalKeyboardKey.arrowLeft => column == 0 ? index : index - 1,
        LogicalKeyboardKey.arrowRight =>
          column == _episodeColumns - 1 || index == _episodeNumbers.length - 1 ? index : index + 1,
        LogicalKeyboardKey.arrowUp => index - _episodeColumns,
        LogicalKeyboardKey.arrowDown => _episodeBelow(index),
        _ => null,
      };
      if (next != null) {
        if (next != index && (event is KeyDownEvent || event is KeyRepeatEvent)) {
          unawaited(_focusEpisode(index, next));
        }

        return KeyEventResult.handled;
      }
    }
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
      ++_episodeNavigationGeneration;
      target?.requestFocus();
      if ((target == _playFocus || target == _favoriteFocus) && MediaQuery.textScalerOf(context).scale(18) <= 18) {
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

  Future<void> _focusEpisode(int from, int to) async {
    final generation = ++_episodeNavigationGeneration;
    final number = _episodeNumbers[to];
    final target = _episodeFocus[number];
    if (target?.context != null) {
      target?.requestFocus();

      return;
    }
    if (!_scrollController.hasClients) {
      return;
    }
    // Build the adjacent virtualized row before requesting its focus node.
    final rowDelta = to ~/ _episodeColumns - from ~/ _episodeColumns;
    final position = _scrollController.position;
    final offset = (position.pixels + rowDelta * (_episodeHeight + AppSpacing.xl)).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    await _scrollController.animateTo(
      offset,
      duration: AppMotion.durationOf(context, AppMotion.fast),
      curve: AppMotion.enterCurve,
    );
    if (!mounted || generation != _episodeNavigationGeneration || ModalRoute.of(context)?.isCurrent == false) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && generation == _episodeNavigationGeneration && _episodeNumbers.contains(number)) {
        final next = _episodeFocus[number];
        if (next?.context != null) {
          next?.requestFocus();
        }
      }
    });
    WidgetsBinding.instance.scheduleFrame();
  }

  void _onEpisodeFocusChanged(BuildContext episodeContext, int number, bool focused) {
    if (!focused) {
      return;
    }
    _focusedEpisodeNumber = number;
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
    if (!AppLayoutScope.isTvOf(context)) {
      unawaited(_refreshMobile());

      return;
    }
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
    _disposed.complete();
    _routeAnimation?.removeStatusListener(_onRouteStatus);
    _playFocus.removeListener(_revealFocusedAction);
    _favoriteFocus.removeListener(_revealFocusedAction);
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
    onKeyEvent: AppLayoutScope.isTvOf(context) ? _handleNavigation : null,
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
          toolbarHeight: AppLayoutScope.isTvOf(context) ? 80 : 56,
          titleSpacing: AppSpacing.lg,
          title: Text(widget.fallbackTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        body: SafeArea(
          top: false,
          child: FutureBuilder<AnimeScreenData>(future: _future, builder: _buildFuture),
        ),
      ),
    ),
  );
}
