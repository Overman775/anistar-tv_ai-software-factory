import 'dart:async';

import 'package:app_logging/app_logging.dart';
import 'package:app_logging/providers.dart';
import 'package:core/data.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';

import '../../../auth/auth_providers.dart';
import '../../../catalog/domain/models/catalog_filter.dart';
import '../../../common/presentation/rating_presentation.dart';
import '../../../favorites/favorites_providers.dart';
import '../../../favorites/presentation/favorite_button.dart';
import '../../../watch_history/watched_episodes.dart';
import '../../anime_providers.dart';
import '../../domain/models/anime_episode.dart';
import '../../domain/models/anime_part.dart';
import '../../domain/models/anime_screen_data.dart';
import '../../domain/repositories/anime_repository.dart';
import '../widgets/anime_detail_filter_actions.dart';
import '../widgets/anime_detail_filter_groups.dart';
import '../widgets/anime_hero.dart';
import '../widgets/anime_layout.dart';
import '../widgets/anime_skeleton.dart';
import '../widgets/anime_watch_order.dart';
import '../widgets/episode_card.dart';
import '../widgets/mobile_anime_content.dart';
import '../widgets/mobile_anime_skeleton.dart';

typedef AnimePlaybackLauncher = Future<void> Function(AnimeEpisode episode, ValueChanged<int> onEpisodeChanged);

class AnimeScreen extends ConsumerStatefulWidget {
  const AnimeScreen({
    required this.animeId,
    required this.slug,
    required this.fallbackTitle,
    this.onEpisodeTap,
    this.onEpisodePlay,
    this.fallbackPosterUri,
    this.onFilterTap,
    this.onPartTap,
    this.embedded = false,
    this.onOpenNavigation,
    super.key,
  }) : assert(onEpisodeTap != null || onEpisodePlay != null);

  final int animeId;
  final bool embedded;
  final VoidCallback? onOpenNavigation;
  final ValueChanged<CatalogFilter>? onFilterTap;
  final ValueChanged<AnimePart>? onPartTap;
  final String fallbackTitle;
  final Uri? fallbackPosterUri;
  final ValueChanged<AnimeEpisode>? onEpisodeTap;
  final AnimePlaybackLauncher? onEpisodePlay;
  final String slug;

  @override
  ConsumerState<AnimeScreen> createState() => _AnimeScreenState();
}

class _AnimeScreenState extends ConsumerState<AnimeScreen> with SingleTickerProviderStateMixin {
  late final _disclosure = AnimationController(vsync: this, animationBehavior: AnimationBehavior.preserve);
  final _scrollController = ScrollController();
  final _contentFocus = FocusScopeNode(debugLabel: 'Карточка аниме');
  final _detailsFocus = FocusNode(debugLabel: 'Подробнее');
  final _favoriteFocus = FocusNode(debugLabel: 'Избранное сериала');
  final _retryFocus = FocusNode(debugLabel: 'Повторить');
  final _episodeGrid = GlobalKey();
  final _episodeFocus = <int, FocusNode>{};
  final _partFocus = <AnimePart, FocusNode>{};
  final _filterFocus = <String, FocusNode>{};
  List<int> _episodeNumbers = [];
  List<CatalogFilter> _filters = [];
  int _episodeColumns = 3;
  double _episodeHeight = 0;
  int? _selectedEpisode;
  int _episodeNavigationGeneration = 0;
  int _playbackGeneration = 0;
  bool _playbackInFlight = false;
  bool _expanded = false;
  bool _closingBackHeld = false;
  bool _initialFocusPending = true;
  bool _initialFocusScheduled = false;

  AnimeScreenData? _data;
  String? _loadError;
  Future<void>? _loadFlight;
  Completer<void>? _loadCancellation;
  int _loadGeneration = 0;
  late (AnimeRepository, String?, bool) _source;

  @override
  void initState() {
    super.initState();
    _source = _readSource();
    unawaited(_load());
  }

  (AnimeRepository, String?, bool) _readSource() {
    final access = ref.read(authAccessProvider);

    return (ref.read(animeRepositoryProvider), access.account, access.canUseAccount);
  }

  Future<void> _load({bool preserveContent = false}) {
    if (_loadFlight case final pending?) return pending;
    if (!preserveContent) _data = null;
    if (_data == null) {
      _loadError = null;
      _initialFocusPending = true;
    }
    final generation = ++_loadGeneration;
    final cancellation = Completer<void>();
    _loadCancellation = cancellation;
    final rememberEpisodes = ref.read(animeKnownEpisodesProvider).beginLoad(widget.animeId, widget.slug);
    final flight = _performLoad(generation, preserveContent, cancellation.future, rememberEpisodes).whenComplete(() {
      if (!cancellation.isCompleted) cancellation.complete();
      if (generation == _loadGeneration) {
        _loadFlight = null;
        _loadCancellation = null;
      }
    });
    _loadFlight = flight;

    return flight;
  }

  Future<void> _performLoad(
    int generation,
    bool preserveContent,
    Future<void> cancellation,
    EpisodeSnapshotWriter rememberEpisodes,
  ) async {
    final logger = ref.read(loggerProvider);
    final revision = ref.read(favoritesControllerProvider).revision;
    final repository = _source.$1;
    try {
      final result = await Future.any<Result<AnimeScreenData, Failure>?>([
        repository.getAnime(id: widget.animeId, slug: widget.slug),
        cancellation.then<Result<AnimeScreenData, Failure>?>((_) => null),
      ]);
      if (!_isCurrentLoad(generation) || result == null) return;

      result.when(
        failure: (failure) => _showFailure(failure.message, preserveContent),
        success: (data) {
          if (data.episodes.isEmpty) {
            _showFailure('У этого аниме пока нет доступных серий.', preserveContent);

            return;
          }
          if (ref.read(favoritesControllerProvider).revision == revision) {
            ref.read(favoritesControllerProvider.notifier).observe(data.details.id, data.details.isFavorite);
          }
          final episodes = data.episodes.toList()..sort((left, right) => right.number.compareTo(left.number));
          if (data.details.id == widget.animeId && data.details.slug == widget.slug) rememberEpisodes(episodes);
          setState(() {
            _data = AnimeScreenData(details: data.details, episodes: episodes);
            _loadError = null;
            if (!episodes.any((episode) => episode.number == _selectedEpisode)) _selectedEpisode = null;
          });
          logger.infoFor<AnimeScreen>('Anime loaded: ${episodes.length} episodes');
        },
      );
    } on Object {
      if (_isCurrentLoad(generation)) {
        _showFailure('Не удалось загрузить данные аниме. Повторите попытку.', preserveContent);
      }
    }
  }

  bool _isCurrentLoad(int generation) => mounted && generation == _loadGeneration && _source == _readSource();

  void _showFailure(String message, bool preserveContent) {
    if (preserveContent && _data != null) {
      if (ModalRoute.isCurrentOf(context) != false) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Не удалось обновить аниме. $message')));
      }

      return;
    }
    setState(() => _loadError = message);
  }

  Future<void> _refreshMobile() {
    if (_loadFlight case final pending?) return pending;
    late Future<void> refresh;
    setState(() {
      refresh = _load(preserveContent: true);
    });

    return refresh;
  }

  void _retry() {
    if (_loadFlight != null) return;
    setState(() => unawaited(_load()));
  }

  void _onSourceChanged() {
    final source = _readSource();
    if (source == _source) return;
    setState(() {
      _source = source;
      _resetRouteData();
    });
  }

  void _resetRouteData() {
    _loadCancellation?.complete();
    ++_episodeNavigationGeneration;
    ++_playbackGeneration;
    _playbackInFlight = false;
    _loadFlight = null;
    _expanded = false;
    _disclosure.value = 0;
    _selectedEpisode = null;
    _episodeNumbers = [];
    _filters = [];
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
    unawaited(_load());
  }

  void _scheduleInitialFocus() {
    if (!_initialFocusPending || _initialFocusScheduled || !AppLayoutScope.isTvOf(context)) return;
    if (_data == null && _loadError == null) return;
    _initialFocusScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initialFocusScheduled = false;
      if (!mounted || !_initialFocusPending || !_contentFocus.hasFocus || ModalRoute.isCurrentOf(context) == false) {
        return;
      }
      _initialFocusPending = false;
      if (!_contentFocus.hasPrimaryFocus) return;
      if (_episodeNumbers.isEmpty) {
        _retryFocus.requestFocus();
      } else {
        unawaited(_focusEpisode(-_episodeColumns, 0));
      }
    });
  }

  void _toggleDetails() {
    setState(() => _expanded = !_expanded);
    final duration = AppMotion.durationOf(context, _expanded ? AppMotion.page : AppMotion.pageReverse);
    if (duration == Duration.zero) {
      _disclosure.value = _expanded ? 1 : 0;
    } else if (_expanded) {
      unawaited(_disclosure.animateTo(1, duration: duration, curve: Curves.easeOutCubic));
    } else {
      unawaited(_disclosure.animateBack(0, duration: duration, curve: Curves.easeOutCubic));
    }
    if (!_expanded && AppLayoutScope.isTvOf(context)) _focusTarget(_detailsFocus);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AppMotion.reducedOf(context) && _disclosure.isAnimating) _disclosure.value = _expanded ? 1 : 0;
  }

  void _openEpisode(AnimeEpisode episode) {
    if (_playbackInFlight || ModalRoute.isCurrentOf(context) == false) return;
    ++_episodeNavigationGeneration;
    setState(() => _selectedEpisode = episode.number);
    final play = widget.onEpisodePlay;
    if (play == null) {
      widget.onEpisodeTap?.call(episode);
    } else {
      unawaited(_restoreEpisodeAfterPlayback(episode, play));
    }
  }

  Future<void> _restoreEpisodeAfterPlayback(AnimeEpisode episode, AnimePlaybackLauncher play) async {
    final generation = ++_playbackGeneration;
    final loadGeneration = _loadGeneration;
    final source = _source;
    var selected = episode.number;
    _playbackInFlight = true;
    try {
      await play(episode, (number) => selected = number);
    } finally {
      if (generation == _playbackGeneration) _playbackInFlight = false;
    }
    if (!mounted || selected == episode.number) return;

    WidgetsBinding.instance
      ..addPostFrameCallback((_) {
        if (!mounted ||
            generation != _playbackGeneration ||
            loadGeneration != _loadGeneration ||
            source != _readSource() ||
            ModalRoute.of(context)?.isCurrent == false) {
          return;
        }
        final index = _episodeNumbers.indexOf(selected);
        if (index < 0) return;
        setState(() => _selectedEpisode = selected);
        if (AppLayoutScope.isTvOf(context)) {
          unawaited(_focusEpisode(_episodeNumbers.indexOf(episode.number), index));
        }
      })
      ..ensureVisualUpdate();
  }

  Widget _errorBody(BuildContext context, String message) {
    final error = TvStateView(
      icon: Icons.cloud_off_rounded,
      title: 'Не удалось загрузить аниме',
      message: message,
      actionLabel: 'Повторить',
      actionFocusNode: _retryFocus,
      autofocusAction: false,
      onAction: _retry,
    );
    if (AppLayoutScope.isTvOf(context)) return error;

    return RefreshIndicator(
      onRefresh: _refreshMobile,
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: error,
          ),
        ),
      ),
    );
  }

  AnimeDisclosure _buildDisclosure(AnimeScreenData data) {
    final details = data.details;
    final groups = AnimeDetailFilterGroups.fromDetails(
      details,
      widget.onFilterTap == null ? const [] : details.filters,
    );
    _filters = [
      for (final row in groups.rows)
        for (final value in row.values) ?value.filter,
    ];
    final parts = details.parts.where((part) => part.label.trim().isNotEmpty).toList();

    return AnimeDisclosure(
      progress: _disclosure,
      expanded: _expanded,
      child: AnimeHero(
        data: data,
        fallbackPosterUri: widget.fallbackPosterUri,
        metadata: AnimeDetailFilterActions(
          groups: groups,
          focusNodes: _filterFocus,
          onSelected: (filter) {
            if (_expanded && ModalRoute.isCurrentOf(context) != false) widget.onFilterTap?.call(filter);
          },
          rating: RatingPresentation.from(details.rating),
        ),
        watchOrder: parts.isEmpty
            ? null
            : AnimeWatchOrder(
                parts: parts,
                currentId: details.id,
                onSelected: widget.onPartTap,
                focusNodes: _partFocus,
              ),
      ),
    );
  }

  Widget _readyBody(BuildContext context, AnimeScreenData data) {
    final tv = AppLayoutScope.isTvOf(context);
    final hasAccount = ref.watch(authAccessProvider).canUseAccount;
    final watched = hasAccount ? ref.watch(watchedEpisodesProvider(widget.animeId)).asData?.value : null;
    final favorite = hasAccount
        ? FavoriteButton(
            focusNode: tv ? _favoriteFocus : null,
            animeId: data.details.id,
            slug: data.details.slug,
            initialFavorite: data.details.isFavorite,
          )
        : null;
    final disclosure = _buildDisclosure(data);
    _episodeNumbers = data.episodes.map((episode) => episode.number).toList(growable: false);
    if (tv) {
      return _tvBody(context, data, favorite, disclosure, watched ?? const <int>{});
    }

    return MobileAnimeContent(
      key: ValueKey(widget.animeId),
      data: data,
      watched: watched ?? const <int>{},
      expanded: _expanded,
      selectedEpisode: _selectedEpisode,
      onToggleDetails: _toggleDetails,
      disclosure: disclosure,
      controller: _scrollController,
      onEpisodeTap: _openEpisode,
      onRefresh: _refreshMobile,
      favoriteAction: favorite,
    );
  }

  Widget _tvBody(BuildContext context, AnimeScreenData data, Widget? favorite, Widget disclosure, Set<int> watched) =>
      CustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl, vertical: AppSpacing.lg),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: AppSpacing.lg,
                children: [
                  Semantics(
                    header: true,
                    child: Text(data.details.title, style: AppContentTypography.detailTitleOf(context)),
                  ),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      Semantics(
                        expanded: _expanded,
                        child: AppButton(
                          label: 'Подробнее',
                          variant: AppButtonVariant.neutral,
                          focusNode: _detailsFocus,
                          icon: RotatedBox(
                            quarterTurns: _expanded ? 3 : 1,
                            child: const AppIcon(AppIconType.chevronRight, size: 20),
                          ),
                          onPressed: _toggleDetails,
                        ),
                      ),
                      ?favorite,
                    ],
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(child: disclosure),
          const SliverPadding(
            padding: EdgeInsets.fromLTRB(AppSpacing.xxl, AppSpacing.lg, AppSpacing.xxl, AppSpacing.sm),
            sliver: SliverToBoxAdapter(child: AppSectionHeader(title: 'Серии')),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.xxl, AppSpacing.sm, AppSpacing.xxl, 72),
            sliver: SliverLayoutBuilder(
              builder: (context, constraints) {
                _episodeColumns = AnimeLayout.episodeColumns(constraints.crossAxisExtent);
                _episodeHeight = AnimeLayout.episodeHeight(context, constraints.crossAxisExtent);

                return SliverGrid.builder(
                  key: _episodeGrid,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: _episodeColumns,
                    mainAxisSpacing: AppSpacing.xl,
                    crossAxisSpacing: AppSpacing.lg,
                    mainAxisExtent: _episodeHeight,
                  ),
                  itemCount: data.episodes.length,
                  findChildIndexCallback: _episodeIndexForKey,
                  itemBuilder: (context, index) {
                    final episode = data.episodes[index];

                    return Builder(
                      key: ValueKey(episode.number),
                      builder: (episodeContext) => EpisodeCard(
                        focusNode: _episodeFocus.putIfAbsent(
                          episode.number,
                          () => FocusNode(debugLabel: episode.title),
                        ),
                        episode: episode,
                        episodeHeight: _episodeHeight,
                        selected: _selectedEpisode == episode.number,
                        isWatched: watched.contains(episode.number),
                        onFocusChanged: (focused) => _revealIfFocused(episodeContext, focused, alignment: 0.58),
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

  int? _episodeIndexForKey(Key key) {
    final index = key is ValueKey<int> ? _episodeNumbers.indexOf(key.value) : -1;

    return index < 0 ? null : index;
  }

  int _episodeBelow(int index) {
    if (index ~/ _episodeColumns == (_episodeNumbers.length - 1) ~/ _episodeColumns) return index;

    return (index + _episodeColumns).clamp(0, _episodeNumbers.length - 1);
  }

  KeyEventResult _handleNavigation(FocusNode node, KeyEvent event) {
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape || key == LogicalKeyboardKey.goBack) {
      if (_expanded && event is KeyDownEvent) {
        _closingBackHeld = true;
        _toggleDetails();

        return KeyEventResult.handled;
      }
      if (_closingBackHeld) {
        if (event is KeyUpEvent) _closingBackHeld = false;

        return KeyEventResult.handled;
      }
    }
    final move = event is KeyDownEvent || event is KeyRepeatEvent;
    final current = FocusManager.instance.primaryFocus;
    final index = _episodeNumbers.indexWhere((number) => identical(_episodeFocus[number], current));
    final parts = _visibleParts;
    final filters = _visibleFilters;
    if (key == LogicalKeyboardKey.arrowLeft &&
        widget.onOpenNavigation != null &&
        (current == _contentFocus ||
            current == _detailsFocus ||
            current == parts.firstOrNull ||
            current == filters.firstOrNull ||
            index >= 0 && index % _episodeColumns == 0)) {
      if (move) {
        _initialFocusPending = false;
        widget.onOpenNavigation?.call();
      }

      return KeyEventResult.handled;
    }
    if (index >= 0) return _handleEpisodeNavigation(index, key, move);
    if (!_isArrowKey(key)) return KeyEventResult.ignored;
    final target = _actionTarget(current, key, parts, filters);
    if (target == null || !target.canRequestFocus || target.context == null) {
      if (key == LogicalKeyboardKey.arrowDown &&
          _episodeNumbers.isNotEmpty &&
          (current == _detailsFocus ||
              current == _favoriteFocus ||
              parts.contains(current) ||
              filters.contains(current))) {
        if (move) unawaited(_focusEpisode(-_episodeColumns, 0));

        return KeyEventResult.handled;
      }

      return KeyEventResult.ignored;
    }
    if (move) _focusTarget(target);

    return KeyEventResult.handled;
  }

  bool _isArrowKey(LogicalKeyboardKey key) =>
      key == LogicalKeyboardKey.arrowLeft ||
      key == LogicalKeyboardKey.arrowRight ||
      key == LogicalKeyboardKey.arrowUp ||
      key == LogicalKeyboardKey.arrowDown;

  KeyEventResult _handleEpisodeNavigation(int index, LogicalKeyboardKey key, bool move) {
    final column = index % _episodeColumns;
    if (key == LogicalKeyboardKey.arrowUp && index < _episodeColumns) {
      final target = _visibleParts.lastOrNull ?? _visibleFilters.lastOrNull ?? _detailsFocus;
      if (move) _focusTarget(target);

      return KeyEventResult.handled;
    }
    final next = switch (key) {
      LogicalKeyboardKey.arrowLeft => column == 0 ? index : index - 1,
      LogicalKeyboardKey.arrowRight =>
        column == _episodeColumns - 1 || index == _episodeNumbers.length - 1 ? index : index + 1,
      LogicalKeyboardKey.arrowUp => index - _episodeColumns,
      LogicalKeyboardKey.arrowDown => _episodeBelow(index),
      _ => null,
    };
    if (next == null) return KeyEventResult.ignored;
    if (next != index && move) unawaited(_focusEpisode(index, next));

    return KeyEventResult.handled;
  }

  List<FocusNode> get _visibleParts => !_expanded
      ? const []
      : [
          for (final part in _data?.details.parts ?? const <AnimePart>[])
            if (_partFocus[part] case final node? when node.context != null && node.canRequestFocus) node,
        ];

  List<FocusNode> get _visibleFilters => !_expanded
      ? const []
      : [
          for (final filter in _filters)
            if (_filterFocus[filter.path] case final node? when node.context != null && node.canRequestFocus) node,
        ];

  FocusNode? _neighborInRow(FocusNode? current, List<FocusNode> targets, {required bool down}) {
    if (current == null || current.context == null) return null;
    final origin = current.rect;
    double bestVertical = double.infinity;
    double bestHorizontal = double.infinity;
    FocusNode? best;
    for (final target in targets) {
      final bounds = target.rect;
      // Wrap aligns row members by their top edge, even with multiline labels.
      final distance = down ? bounds.top - origin.top : origin.top - bounds.top;
      if (distance < 0.5) continue;
      final horizontal = (origin.center.dx - bounds.center.dx).abs();
      if (distance < bestVertical - 0.5 || (distance <= bestVertical + 0.5 && horizontal < bestHorizontal)) {
        best = target;
        bestVertical = distance;
        bestHorizontal = horizontal;
      }
    }

    return best;
  }

  FocusNode? _actionTarget(FocusNode? current, LogicalKeyboardKey key, List<FocusNode> parts, List<FocusNode> filters) {
    final inParts = parts.contains(current);
    final targets = inParts ? parts : filters;
    final index = targets.indexWhere((node) => identical(node, current));
    if (index >= 0) {
      return switch (key) {
        LogicalKeyboardKey.arrowUp =>
          _neighborInRow(current, targets, down: false) ?? (inParts ? filters.lastOrNull : null) ?? _detailsFocus,
        LogicalKeyboardKey.arrowDown =>
          _neighborInRow(current, targets, down: true) ?? (inParts ? null : parts.firstOrNull),
        LogicalKeyboardKey.arrowLeft => targets.elementAtOrNull(index - 1) ?? current,
        LogicalKeyboardKey.arrowRight => targets.elementAtOrNull(index + 1) ?? current,
        _ => null,
      };
    }
    if (current == _detailsFocus || current == _favoriteFocus) {
      return switch (key) {
        LogicalKeyboardKey.arrowDown => filters.firstOrNull ?? parts.firstOrNull,
        LogicalKeyboardKey.arrowUp => current,
        LogicalKeyboardKey.arrowRight when current == _detailsFocus =>
          _favoriteFocus.context == null ? current : _favoriteFocus,
        LogicalKeyboardKey.arrowLeft when current == _favoriteFocus => _detailsFocus,
        _ => null,
      };
    }

    return null;
  }

  void _focusTarget(FocusNode target) {
    ++_episodeNavigationGeneration;
    target.requestFocus();
    if (target == _detailsFocus || target == _favoriteFocus) {
      if (target.context case final targetContext?) _revealIfFocused(targetContext, true);
    }
  }

  Future<void> _focusEpisode(int from, int to) async {
    final generation = ++_episodeNavigationGeneration;
    final number = _episodeNumbers[to];
    final target = _episodeFocus[number];
    if (target?.context != null) {
      target?.requestFocus();

      return;
    }
    if (!_scrollController.hasClients) return;
    final gridContext = _episodeGrid.currentContext;
    if (from < 0 && gridContext != null) {
      await Scrollable.ensureVisible(gridContext);
    } else {
      final rowDelta = to ~/ _episodeColumns - from ~/ _episodeColumns;
      final position = _scrollController.position;
      final offset = (position.pixels + rowDelta * (_episodeHeight + AppSpacing.xl)).clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      );
      final duration = AppMotion.durationOf(context, AppMotion.fast);
      if (duration == Duration.zero) {
        _scrollController.jumpTo(offset);
      } else {
        await _scrollController.animateTo(offset, duration: duration, curve: AppMotion.enterCurve);
      }
    }
    if (!mounted || generation != _episodeNavigationGeneration || ModalRoute.isCurrentOf(context) == false) return;
    WidgetsBinding.instance
      ..addPostFrameCallback((_) {
        if (mounted && generation == _episodeNavigationGeneration && _episodeNumbers.contains(number)) {
          final next = _episodeFocus[number];
          if (next?.context != null) next?.requestFocus();
        }
      })
      ..ensureVisualUpdate();
  }

  void _revealIfFocused(BuildContext target, bool focused, {double alignment = 0.5}) {
    if (!focused) return;
    unawaited(
      Scrollable.ensureVisible(
        target,
        alignment: alignment,
        duration: AppMotion.durationOf(context, AppMotion.standard),
        curve: AppMotion.enterCurve,
      ),
    );
  }

  @override
  void didUpdateWidget(covariant AnimeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animeId != widget.animeId || oldWidget.slug != widget.slug) _resetRouteData();
  }

  @override
  void dispose() {
    _loadCancellation?.complete();
    _disclosure.dispose();
    _scrollController.dispose();
    _contentFocus.dispose();
    _detailsFocus.dispose();
    _favoriteFocus.dispose();
    _retryFocus.dispose();
    for (final node in [..._partFocus.values, ..._filterFocus.values, ..._episodeFocus.values]) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref
      ..listen(animeRepositoryProvider, (_, _) => _onSourceChanged())
      ..listen(
        authAccessProvider.select((access) => (access.account, access.canUseAccount)),
        (_, _) => _onSourceChanged(),
      );
    final tv = AppLayoutScope.isTvOf(context);
    final body = switch ((_data, _loadError)) {
      (final data?, _) => _readyBody(context, data),
      (_, final message?) => _errorBody(context, message),
      _ => tv ? AnimeSkeleton(title: widget.fallbackTitle) : MobileAnimeSkeleton(title: widget.fallbackTitle),
    };
    _scheduleInitialFocus();

    return PopScope(
      canPop: !tv || !_expanded,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && tv && _expanded && _contentFocus.hasFocus) _toggleDetails();
      },
      child: FocusScope(
        node: _contentFocus,
        autofocus: tv,
        onFocusChange: (focused) {
          if (focused) {
            _scheduleInitialFocus();
          } else {
            _initialFocusPending = false;
            _closingBackHeld = false;
            ++_episodeNavigationGeneration;
          }
        },
        onKeyEvent: tv ? _handleNavigation : null,
        child: TvBackdrop(
          child: Scaffold(
            backgroundColor: Colors.transparent,
            appBar: tv || widget.embedded
                ? null
                : AppBar(
                    leading: ModalRoute.canPopOf(context) == true
                        ? IconButton(
                            tooltip: 'Назад к каталогу',
                            onPressed: () => Navigator.of(context).maybePop(),
                            icon: const AppIcon(AppIconType.arrowLeft),
                          )
                        : null,
                    backgroundColor: Colors.transparent,
                    surfaceTintColor: Colors.transparent,
                    flexibleSpace: const TvHeaderSurface(),
                  ),
            body: SafeArea(top: false, child: body),
          ),
        ),
      ),
    );
  }
}
