import 'dart:async';

import 'package:app_logging/providers.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';

import '../../../auth/auth_providers.dart';
import '../../../favorites/favorite_catalog_status_provider.dart';
import '../../../favorites/favorites_providers.dart';
import '../../../favorites/presentation/favorite_actions_sheet.dart';
import '../../../favorites/presentation/favorite_button.dart';
import '../../catalog_providers.dart';
import '../../domain/models/anime_summary.dart';
import '../../domain/models/catalog_filter.dart';
import '../../domain/models/catalog_sort.dart';
import '../../domain/repositories/catalog_repository.dart';
import '../../domain/repositories/filtered_catalog_repository.dart';
import '../bloc/catalog_bloc.dart';
import '../bloc/catalog_event.dart';
import '../bloc/catalog_state.dart';
import '../mobile/mobile_anime_card.dart';
import '../widgets/anime_card.dart';
import '../widgets/catalog_inspector.dart';
import '../widgets/catalog_layout.dart';
import '../widgets/catalog_poster_rail.dart';
import '../widgets/catalog_skeleton.dart';
import '../widgets/catalog_sort_sheet.dart';
import '../widgets/catalog_tail.dart';

class CatalogScreen extends ConsumerStatefulWidget {
  const CatalogScreen({
    required this.onAnimeTap,
    this.onOpenNavigation,
    this.onWatchAnime,
    this.onFilterSelected,
    this.filter,
    this.onTabSelected,
    this.favoritesOnly = false,
    this.active = true,
    super.key,
  });

  final VoidCallback? onOpenNavigation;
  final CatalogFilter? filter;
  final ValueChanged<CatalogFilter>? onFilterSelected;
  final bool favoritesOnly;
  final bool active;
  final ValueChanged<AnimeSummary> onAnimeTap;
  final ValueChanged<AnimeSummary>? onWatchAnime;
  final ValueChanged<bool>? onTabSelected;

  @override
  ConsumerState<CatalogScreen> createState() => CatalogScreenState();
}

class CatalogScreenState extends ConsumerState<CatalogScreen> {
  late CatalogBloc _bloc;
  final _disposed = Completer<void>();
  Future<void>? _mobileRefresh;
  FilteredCatalogRepository? _filteredRepository;
  final _sortFocus = FocusNode(debugLabel: 'Сортировка');
  FocusNode? _sortOrigin;
  CatalogSort _confirmedSort = defaultCatalogSort;
  bool _sortSheetOpen = false;
  final ScrollController _scrollController = ScrollController();
  final _contentFocus = FocusScopeNode(debugLabel: 'Каталог');
  bool _pendingFirst = false;
  bool _initialFilteredLoad = true;
  bool _sortInteracted = false;
  bool _keepSortFocus = false;
  FocusNode? _lastCardFocus;
  int _selectedIndex = 0;
  int? _selectedId;
  bool _inspectImmediately = false;
  final _cardFocus = <int, FocusNode>{};
  final _watchFocus = FocusNode(debugLabel: 'Смотреть');
  final _favoriteFocus = FocusNode(debugLabel: 'Избранное тайтла');
  final _lastGenreFocus = FocusNode();
  final _retryFocus = FocusNode(debugLabel: 'Повторить загрузку каталога');
  bool _routeActive = true;
  bool _returnToPoster = false;
  int? _replacementFocusId;
  int? _pendingNextFrom;
  late (Object, String?, bool) _sourceKey;

  bool get _tvActive => mounted && widget.active && _routeActive;

  String get _railTitle => widget.filter?.label ?? (widget.favoritesOnly ? 'Избранное' : 'Каталог аниме');

  FocusNode _focusFor(int id) => _cardFocus.putIfAbsent(id, () => FocusNode(debugLabel: 'Постер $id'));

  AnimeSummary? _selected(List<AnimeSummary> items) {
    final indexed = items.elementAtOrNull(_selectedIndex);
    if (_selectedId == null || indexed?.id == _selectedId) return indexed ?? items.lastOrNull;

    return items.where((item) => item.id == _selectedId).firstOrNull ?? indexed ?? items.lastOrNull;
  }

  @override
  void initState() {
    super.initState();
    _startCatalog();
    _scrollController.addListener(_onScroll);
    _watchFocus.addListener(_revealAction);
    _favoriteFocus.addListener(_revealAction);
  }

  void _startCatalog() {
    _confirmedSort = defaultCatalogSort;
    final filter = widget.filter;
    final browse = filter == null ? null : ref.read(catalogBrowseRepositoryProvider);
    _filteredRepository = browse == null || filter == null ? null : FilteredCatalogRepository(browse, filter);
    final CatalogRepository repository =
        _filteredRepository ??
        (widget.favoritesOnly ? ref.read(favoritesRepositoryProvider) : ref.read(catalogRepositoryProvider));
    final access = ref.read(authAccessProvider);
    _sourceKey = (browse ?? repository, access.account, access.canUseAccount);
    _bloc = CatalogBloc(repository: repository, logger: ref.read(loggerProvider))..add(const CatalogStarted());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final wasActive = _routeActive;
    final routeCurrent = ModalRoute.isCurrentOf(context) ?? true;
    final sectionEnabled = TickerMode.valuesOf(context).enabled;
    _routeActive = routeCurrent && sectionEnabled;
    if (!_tvActive) _clearContinuationIntent();
    if (_tvActive && !wasActive && _returnToPoster) {
      _returnToPoster = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_tvActive) focusFirst();
      });
    }
  }

  void focusFirst() {
    _pendingNextFrom = null;
    final state = _bloc.state;
    if (_selected(state.items) case final selected?) {
      _pendingFirst = false;
      _focusFor(selected.id).requestFocus();

      return;
    }
    final action = _contentFocus.traversalDescendants
        .where((node) => node.canRequestFocus && node.context?.findAncestorWidgetOfExactType<TvStateView>() != null)
        .firstOrNull;
    _pendingFirst = state is CatalogInitial || state is CatalogLoading;
    (action ?? _contentFocus).requestFocus();
  }

  void refresh() => _bloc.add(const CatalogStarted(preserveContent: true, preservePages: true));

  void _focusContent() {
    final previous = _lastCardFocus;
    if (previous?.context != null && previous?.canRequestFocus == true) {
      previous?.requestFocus();
    } else {
      final hasItems = _bloc.state.items.isNotEmpty;
      (_contentFocus.traversalDescendants
                  .where(
                    (node) =>
                        node.canRequestFocus &&
                        node.context != null &&
                        (hasItems
                            ? node.context?.findAncestorWidgetOfExactType<AnimeCard>() != null
                            : node.context?.findAncestorWidgetOfExactType<TvStateView>() != null),
                  )
                  .firstOrNull ??
              (widget.filter != null ? _sortFocus : _contentFocus))
          .requestFocus();
    }
  }

  void _focusRail() {
    _pendingNextFrom = null;
    _replacementFocusId = null;
    if (widget.onOpenNavigation case final onOpenNavigation?) {
      onOpenNavigation();

      return;
    }
    _focusContent();
  }

  Widget _buildState(BuildContext context, CatalogState state) {
    if (state is CatalogInitial || state is CatalogLoading) {
      return CatalogSkeleton(title: _railTitle);
    }
    if (state is CatalogFailure && state.items.isEmpty) {
      return TvStateView(
        icon: Icons.cloud_off_rounded,
        title: widget.favoritesOnly ? 'Избранное недоступно' : 'Каталог недоступен',
        message: state.message,
        actionLabel: 'Попробовать снова',
        onAction: _reload,
      );
    }
    if (state.items.isEmpty) {
      return TvStateView(
        icon: widget.favoritesOnly ? Icons.favorite_border_rounded : Icons.video_library_outlined,
        title: widget.favoritesOnly ? 'Избранное пусто' : 'Каталог пуст',
        message: widget.favoritesOnly
            ? 'Добавьте сериал с главной страницы или из его карточки.'
            : 'На сайте AniStar не найдено аниме.',
        actionLabel: widget.favoritesOnly && widget.onTabSelected != null ? 'Перейти на главную' : null,
        onAction: widget.favoritesOnly && widget.onTabSelected != null ? () => widget.onTabSelected?.call(false) : null,
        actionIcon: Icons.video_library_outlined,
        autofocusAction: false,
      );
    }

    if (!AppLayoutScope.isTvOf(context)) {
      return _mobileGrid(state);
    }

    final anime = _selected(state.items);
    if (anime == null) return const SizedBox.shrink();

    return Consumer(
      builder: (context, cardRef, _) {
        final favoriteIds = _favoriteIds(state, cardRef);
        final canUseAccount = cardRef.watch(authAccessProvider).canUseAccount;
        final favorites = cardRef.watch(favoritesControllerProvider);
        bool? isFavorite(AnimeSummary item) =>
            favorites.confirmedStatus(item.id, reported: item.isFavorite, listed: favoriteIds.contains(item.id));

        return CatalogInspector(
          anime: anime,
          immediate: _inspectImmediately,
          trailingInset: widget.filter == null ? 0 : _sortMaxWidth(context) + AppSpacing.md,
          actions: _inspectorActions(anime, canUseAccount, isFavorite(anime)),
          lastGenreFocus: _lastGenreFocus,
          onGenreTap: widget.onFilterSelected == null ? null : _openGenre,
          onGenreTop: widget.filter == null ? null : _focusSortFrom,
          onGenreRight: widget.filter == null ? null : _focusSortFrom,
          onGenreBottom: _watchFocus.requestFocus,
          rail: _posterRail(context, state, anime, isFavorite, canUseAccount),
        );
      },
    );
  }

  Widget _inspectorActions(AnimeSummary anime, bool canUseAccount, bool? favorite) => Focus(
    canRequestFocus: false,
    onKeyEvent: (_, event) {
      final key = event.logicalKey;
      final move = event is KeyDownEvent || event is KeyRepeatEvent;
      final origin = _favoriteFocus.hasFocus ? _favoriteFocus : _watchFocus;
      if (key == LogicalKeyboardKey.arrowDown) {
        if (move) _focusContent();

        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.arrowUp) {
        if (move) {
          if (_canFocus(_lastGenreFocus)) {
            _lastGenreFocus.requestFocus();
          } else {
            _focusSortFrom(origin);
          }
        }

        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.arrowLeft && _favoriteFocus.hasFocus) {
        if (move) _watchFocus.requestFocus();

        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.arrowRight) {
        if (move) {
          if (_watchFocus.hasFocus && canUseAccount && _canFocus(_favoriteFocus)) {
            _favoriteFocus.requestFocus();
          } else {
            _focusSortFrom(origin);
          }
        }

        return KeyEventResult.handled;
      }

      return KeyEventResult.ignored;
    },
    child: Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        AppButton(
          label: 'Смотреть',
          focusNode: _watchFocus,
          minHeight: CatalogLayout.inspectorActionMinHeight,
          icon: const AppIcon(AppIconType.play, size: 20),
          onPressed: _openSelected,
        ),
        if (canUseAccount)
          FavoriteButton(
            animeId: anime.id,
            slug: anime.slug,
            initialFavorite: favorite ?? (widget.favoritesOnly ? true : null),
            focusNode: _favoriteFocus,
            minHeight: CatalogLayout.inspectorActionMinHeight,
          ),
      ],
    ),
  );

  bool _canFocus(FocusNode? node) => node?.context != null && node?.canRequestFocus == true;

  void _focusSortFrom(FocusNode origin) {
    if (!_canFocus(_sortFocus)) return;
    _sortOrigin = origin;
    _sortFocus.requestFocus();
  }

  void _revealAction() {
    final focused = _watchFocus.hasFocus ? _watchFocus : _favoriteFocus;
    if (focused.hasFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (focused.context case final target? when mounted && focused.hasFocus) {
          unawaited(Scrollable.ensureVisible(target));
        }
      });
    }
  }

  void _openSelected() {
    _pendingNextFrom = null;
    if (_selected(_bloc.state.items) case final item?) {
      _returnToPoster = true;
      (widget.onWatchAnime ?? widget.onAnimeTap)(item);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_tvActive) _returnToPoster = false;
      });
    }
  }

  void _openGenre(AnimeSummary anime, CatalogFilter filter) {
    if (_selected(_bloc.state.items)?.id == anime.id) widget.onFilterSelected?.call(filter);
  }

  Widget _posterRail(
    BuildContext context,
    CatalogState state,
    AnimeSummary selected,
    bool? Function(AnimeSummary) isFavorite,
    bool canUseAccount,
  ) {
    final bloc = _bloc;
    final loadingMore = state is CatalogReady && state.isLoadingMore;
    final failure = state is CatalogFailure ? state : null;

    return CatalogPosterRail(
      controller: _scrollController,
      heading: Text(
        _railTitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      items: state.items,
      selectedId: selected.id,
      active: _tvActive,
      loadingMore: loadingMore,
      continuationIdentity: state is CatalogReady && state.hasMore ? state : null,
      unloadedCount: failure != null || !state.hasMore ? 0 : CatalogLayout.continuationSlots(state.nextPageSize),
      onVisibleContinuation: () {
        if (!_tvActive || !identical(bloc, _bloc) || !identical(bloc.state, state)) return;
        bloc.add(
          CatalogMoreRequested(canStart: () => _tvActive && identical(bloc, _bloc) && identical(bloc.state, state)),
        );
      },
      tail: failure == null ? null : CatalogTail(error: failure.message, onRetry: _requestMore, focusNode: _retryFocus),
      onKeyEvent: _handleCatalogKey,
      itemBuilder: (context, anime, index, step) {
        final isSelected = selected.id == anime.id;

        return AnimeCard(
          anime: anime,
          rail: true,
          selected: isSelected,
          isFavorite: isFavorite(anime),
          showFavorite: !widget.favoritesOnly && canUseAccount,
          focusNode: _focusFor(anime.id),
          autofocus: !_keepSortFocus && isSelected,
          onFocusChanged: (focused) => _onCardFocusChanged(anime.id, index, step, focused),
          onLongPressed: () => unawaited(_favoriteActions(anime)),
          onTap: () {
            _pendingNextFrom = null;
            _updateSelection(anime, index, step);
            widget.onAnimeTap(anime);
          },
        );
      },
    );
  }

  Future<void> _refreshMobile() => _mobileRefresh ??= _performMobileRefresh().whenComplete(() => _mobileRefresh = null);

  Future<void> _performMobileRefresh() async {
    final bloc = _bloc;
    // Revision must be sampled again after the asynchronous refresh.
    final revision = ref.read(favoritesControllerProvider).revision;
    // Logout can dispose the catalog while the refresh request is pending.
    // Wait for the refresh's terminal state, never a preceding pagination result.
    final completion = bloc.stream
        .skipWhile((state) => state is! CatalogRefreshing)
        .skip(1)
        .firstWhere((state) => state is CatalogReady || state is CatalogFailure, orElse: () => bloc.state);
    bloc.add(const CatalogStarted(preserveContent: true));
    await Future.any<void>([completion.then<void>((_) => null), _disposed.future]);
    if (!mounted || !identical(bloc, _bloc)) {
      return;
    }
    final state = bloc.state;
    // The current revision protects writes confirmed while the request was pending.
    if (state is CatalogReady && ref.read(favoritesControllerProvider).revision == revision) {
      final favorites = ref.read(favoritesControllerProvider.notifier)..invalidate();
      for (final anime in state.items) {
        favorites.observe(anime.id, anime.isFavorite);
      }
    } else if (state is CatalogFailure && state.items.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Не удалось обновить. ${state.message}')));
    }
  }

  Set<int> _favoriteIds(CatalogState state, WidgetRef cardRef) => watchFavoriteMembership(
    cardRef,
    state.items,
    active:
        !widget.favoritesOnly &&
        _tvActive &&
        TickerMode.valuesOf(cardRef.context).enabled &&
        cardRef.watch(authAccessProvider).canUseAccount,
  );

  Widget _mobileGrid(CatalogState state) => Consumer(
    builder: (context, cardRef, child) {
      final favoriteIds = _favoriteIds(state, cardRef);
      final favorites = cardRef.watch(favoritesControllerProvider);
      return LayoutBuilder(
        builder: (context, constraints) {
          final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
          final horizontalPadding = AppLayoutScope.horizontalPaddingOf(context);
          final available = constraints.maxWidth - horizontalPadding * 2;
          final columns = CatalogLayout.mobileColumnCount(
            available,
            scale,
            landscape: MediaQuery.orientationOf(context) == Orientation.landscape,
          );
          const gap = CatalogLayout.mobilePosterGap;
          final width = (available - (columns - 1) * gap) / columns;
          final tail =
              state is CatalogFailure && !state.isRefreshFailure || state is CatalogReady && state.isLoadingMore;

          return CustomScrollView(
            key: PageStorageKey(('mobile-catalog', widget.favoritesOnly, widget.filter?.path)),
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              if (widget.filter case final filter?) SliverToBoxAdapter(child: _mobileFilterHeader(context, filter)),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(horizontalPadding, 8, horizontalPadding, 24),
                sliver: SliverGrid.builder(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    mainAxisExtent: width / AppSizes.posterRatio,
                    crossAxisSpacing: gap,
                    mainAxisSpacing: 20,
                  ),
                  itemCount: state.items.length,
                  itemBuilder: (context, index) {
                    final anime = state.items[index];

                    return MobileAnimeCard(
                      key: ValueKey(anime.id),
                      anime: anime,
                      isFavorite: favorites.confirmedStatus(
                        anime.id,
                        reported: anime.isFavorite,
                        listed: favoriteIds.contains(anime.id),
                      ),
                      showFavorite: !widget.favoritesOnly && cardRef.read(authAccessProvider).canUseAccount,
                      showRating: !widget.favoritesOnly && widget.filter == null,
                      onTap: () => _selectAndOpen(anime, index),
                      onActions: () => unawaited(_favoriteActions(anime)),
                    );
                  },
                ),
              ),
              if (tail)
                SliverToBoxAdapter(
                  child: CatalogTail(error: state is CatalogFailure ? state.message : null, onRetry: _requestMore),
                ),
              SliverPadding(padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom)),
            ],
          );
        },
      );
    },
  );

  Widget _mobileFilterHeader(BuildContext context, CatalogFilter filter) => Padding(
    padding: EdgeInsets.symmetric(horizontal: AppLayoutScope.horizontalPaddingOf(context), vertical: AppSpacing.sm),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: AppSpacing.sm,
      children: [
        Semantics(header: true, child: Text(filter.label, style: Theme.of(context).textTheme.headlineSmall)),
        _sortControls(tv: false),
      ],
    ),
  );

  Widget _mobileScreen() => BlocProvider.value(
    value: _bloc,
    child: Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _refreshMobile,
          child: BlocConsumer<CatalogBloc, CatalogState>(
            bloc: _bloc,
            listener: _onCatalogStateChanged,
            buildWhen: (previous, current) => previous != current,
            builder: (context, state) {
              if (state.items.isNotEmpty) return _mobileGrid(state);
              final loading = state is CatalogLoading || state is CatalogInitial;
              final feedback = loading ? const Center(child: CircularProgressIndicator()) : _buildState(context, state);
              final filter = widget.filter;
              if (filter == null && loading) return feedback;

              return LayoutBuilder(
                builder: (context, constraints) => CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    if (filter != null) SliverToBoxAdapter(child: _mobileFilterHeader(context, filter)),
                    SliverToBoxAdapter(
                      child: SizedBox(
                        height: (constraints.maxHeight - MediaQuery.paddingOf(context).bottom).clamp(
                          0.0,
                          double.infinity,
                        ),
                        child: feedback,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    ),
  );

  KeyEventResult _handleCatalogKey(KeyEvent event, double step) {
    final key = event.logicalKey;
    final state = _bloc.state;
    if (key != LogicalKeyboardKey.arrowLeft &&
        key != LogicalKeyboardKey.arrowRight &&
        key != LogicalKeyboardKey.arrowUp &&
        key != LogicalKeyboardKey.arrowDown) {
      return KeyEventResult.ignored;
    }
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.handled;

    _replacementFocusId = null;
    if (key != LogicalKeyboardKey.arrowRight) _pendingNextFrom = null;
    if (_retryFocus.hasFocus) {
      if (key == LogicalKeyboardKey.arrowLeft) _focusContent();

      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      final selected = _selected(state.items)?.id;
      setState(() => _inspectImmediately = true);
      if (_watchFocus.canRequestFocus) {
        _watchFocus.requestFocus();
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_tvActive && _inspectImmediately && _selected(_bloc.state.items)?.id == selected) {
            _watchFocus.requestFocus();
          }
        });
      }
    } else if (key == LogicalKeyboardKey.arrowLeft) {
      if (_selectedIndex == 0) {
        _focusRail();
      } else {
        _moveCard(_selectedIndex - 1, step);
      }
    } else if (key == LogicalKeyboardKey.arrowRight) {
      if (_selectedIndex < state.items.length - 1) {
        _moveCard(_selectedIndex + 1, step);
      } else if (state is CatalogFailure && _retryFocus.context != null) {
        _retryFocus.requestFocus();
      } else if (_tvActive && state is CatalogReady && state.hasMore) {
        _pendingNextFrom = state.items.lastOrNull?.id;
      }
    }

    return KeyEventResult.handled;
  }

  void _moveCard(int index, double step) {
    final anime = _bloc.state.items.elementAtOrNull(index);
    if (anime == null) return;
    _updateSelection(anime, index, step);
    _focusFor(anime.id).requestFocus();
  }

  KeyEventResult _handleContentKey(FocusNode node, KeyEvent event) {
    if (widget.filter != null && _bloc.state.items.isEmpty && event.logicalKey == LogicalKeyboardKey.arrowUp) {
      if (event is KeyDownEvent || event is KeyRepeatEvent) {
        _sortFocus.requestFocus();
      }

      return KeyEventResult.handled;
    }
    final fromCard = FocusManager.instance.primaryFocus?.context?.findAncestorWidgetOfExactType<AnimeCard>() != null;
    final fromInspector =
        FocusManager.instance.primaryFocus?.context?.findAncestorWidgetOfExactType<CatalogInspector>() != null;
    if (fromCard || fromInspector || event.logicalKey != LogicalKeyboardKey.arrowLeft) {
      return KeyEventResult.ignored;
    }
    if (event is KeyDownEvent) {
      _focusRail();
    }

    return KeyEventResult.handled;
  }

  Future<void> _favoriteActions(AnimeSummary anime) async {
    _pendingNextFrom = null;
    await showFavoriteActions(context, animeId: anime.id, slug: anime.slug, title: anime.title);
    if (mounted && AppLayoutScope.isTvOf(context) && _lastCardFocus?.context == null) {
      _focusRail();
    }
  }

  void _onCatalogStateChanged(BuildContext context, CatalogState state) {
    if (state is CatalogReady && identical(state, _bloc.state)) {
      final confirmed = state.confirmedSort;
      if (confirmed != null && confirmed == _filteredRepository?.sort && _confirmedSort != confirmed) {
        setState(() => _confirmedSort = confirmed);
      }
    }
    final pendingActivation = _pendingFirst && _contentFocus.hasFocus;
    if (_pendingFirst && state is! CatalogLoading && state is! CatalogInitial) {
      _pendingFirst = false;
      if (pendingActivation) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _contentFocus.hasFocus) {
            focusFirst();
          }
        });
      }
    }
    if (!AppLayoutScope.isTvOf(context)) {
      return;
    }
    _restorePendingContinuationFocus(state);
    if (state is CatalogReady) _reconcileSelection(state);
    if (_keepSortFocus && state is CatalogReady && state.items.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _keepSortFocus && ModalRoute.of(context)?.isCurrent == true) {
          _sortFocus.requestFocus();
        }
      });
    }
    if (_initialFilteredLoad && state is! CatalogInitial && state is! CatalogLoading) {
      _initialFilteredLoad = false;
      if (widget.filter != null && !_sortInteracted && state is CatalogReady && state.items.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && ModalRoute.of(context)?.isCurrent == true && _sortFocus.hasFocus) {
            _focusContent();
          }
        });
      }
    }
    final emptyActionFocused =
        widget.favoritesOnly &&
        widget.onTabSelected != null &&
        _contentFocus.hasFocus &&
        FocusManager.instance.primaryFocus?.context?.findAncestorWidgetOfExactType<TvStateView>() != null;
    if (state is CatalogReady &&
        state.items.isEmpty &&
        !pendingActivation &&
        !emptyActionFocused &&
        _contentFocus.hasFocus &&
        ModalRoute.of(context)?.isCurrent == true) {
      _focusRail();
    }
  }

  void _reconcileSelection(CatalogReady state) {
    final previous = _selectedId;
    if (previous == null) return;
    if (state.items.isEmpty) {
      _selectedIndex = 0;
      _selectedId = null;
      _lastCardFocus = null;
      if (widget.favoritesOnly && _tvActive) _focusRail();

      return;
    }
    final index = state.items.indexWhere((item) => item.id == previous);
    if (index >= 0) {
      _selectedIndex = index;

      return;
    }
    final shouldRestore = _tvActive && _contentFocus.hasFocus && !_keepSortFocus;
    _selectedIndex = _selectedIndex.clamp(0, state.items.length - 1);
    final replacement = state.items[_selectedIndex];
    _selectedId = replacement.id;
    final target = _lastCardFocus = _focusFor(replacement.id);
    if (!shouldRestore) return;
    _replacementFocusId = replacement.id;
    final bloc = _bloc;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_replacementFocusId != replacement.id) return;
      if (!_tvActive || bloc != _bloc) {
        _replacementFocusId = null;

        return;
      }
      target.requestFocus();
    });
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.axis == Axis.vertical && position.extentAfter < 500 && _canPreload) {
      _bloc.add(const CatalogMoreRequested());
    }
  }

  void _clearContinuationIntent() {
    _pendingNextFrom = null;
    _replacementFocusId = null;
  }

  void _restorePendingContinuationFocus(CatalogState state) {
    final id = _pendingNextFrom;
    if (id == null) return;
    if (!_tvActive || state is! CatalogReady) {
      _pendingNextFrom = null;

      return;
    }
    final index = state.items.indexWhere((item) => item.id == id);
    if (index < 0 || (index + 1 == state.items.length && !state.hasMore)) {
      _pendingNextFrom = null;

      return;
    }
    final next = state.items.elementAtOrNull(index + 1);
    if (next == null) return;
    final bloc = _bloc;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_tvActive || !identical(bloc, _bloc) || _pendingNextFrom != id || _cardFocus[id]?.hasPrimaryFocus != true) {
        return;
      }
      _pendingNextFrom = null;
      if (bloc.state.items.elementAtOrNull(index + 1)?.id != next.id) return;
      final viewport = MediaQuery.sizeOf(context);
      final step = CatalogLayout.posterWidth(viewport.height) + CatalogLayout.posterGap(viewport.width);
      _moveCard(index + 1, step);
    });
  }

  bool get _canPreload {
    final state = _bloc.state;

    return state.hasMore && (state is CatalogReady || state is CatalogFailure && state.isRefreshFailure);
  }

  void _onCardFocusChanged(int id, int index, double step, bool focused) {
    if (!focused) {
      if (_pendingNextFrom == id) _pendingNextFrom = null;

      return;
    }
    final replacement = _replacementFocusId;
    if (replacement != null && replacement != id) return;
    _replacementFocusId = null;
    final anime = _bloc.state.items.elementAtOrNull(index);
    if (anime == null || anime.id != id) return;
    _keepSortFocus = false;
    _lastCardFocus = _focusFor(anime.id);
    _updateSelection(anime, index, step);
  }

  void _updateSelection(AnimeSummary anime, int index, double step) {
    if (_selectedIndex == index && _selectedId == anime.id) return;
    _pendingNextFrom = null;
    setState(() {
      _selectedId = anime.id;
      _selectedIndex = index;
      _inspectImmediately = false;
    });
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    final target = (index * step).clamp(position.minScrollExtent, position.maxScrollExtent);
    final duration = AppMotion.durationOf(context, CatalogLayout.railMotion);
    if (duration == Duration.zero) {
      _scrollController.jumpTo(target);
    } else if (target != position.pixels || position.isScrollingNotifier.value) {
      unawaited(_scrollController.animateTo(target, duration: duration, curve: Curves.easeOutCubic));
    }
  }

  Future<void> _chooseSort() async {
    if (_sortSheetOpen || _filteredRepository == null) return;
    _sortInteracted = true;
    _sortSheetOpen = true;
    final bloc = _bloc;
    final initial = _confirmedSort;
    final CatalogSort? selected;
    try {
      selected = await showAppActionSheet<CatalogSort>(
        context: context,
        builder: (_) => CatalogSortSheet(selected: initial),
      );
    } finally {
      _sortSheetOpen = false;
    }
    if (!mounted || !identical(bloc, _bloc)) {
      return;
    }
    if (AppLayoutScope.isTvOf(context)) {
      _sortFocus.requestFocus();
    }
    final current = _filteredRepository;
    final applied = selected;
    if (applied == null ||
        current == null ||
        applied == initial ||
        applied == current.sort && bloc.state is! CatalogFailure) {
      return;
    }
    final next = FilteredCatalogRepository(current.repository, current.filter, sort: applied);
    setState(() {
      _keepSortFocus = true;
      _sortOrigin = null;
      _filteredRepository = next;
      _selectedIndex = 0;
      _selectedId = null;
      _lastCardFocus = null;
    });
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
    bloc.add(CatalogStarted(repository: next));
  }

  KeyEventResult _handleSortKey(FocusNode node, KeyEvent event) {
    _sortInteracted = true;
    final key = event.logicalKey;
    if (![
      LogicalKeyboardKey.arrowDown,
      LogicalKeyboardKey.arrowLeft,
      LogicalKeyboardKey.arrowUp,
      LogicalKeyboardKey.arrowRight,
    ].contains(key)) {
      return KeyEventResult.ignored;
    }
    if (event is KeyDownEvent || event is KeyRepeatEvent) {
      if (key == LogicalKeyboardKey.arrowDown) {
        _focusContent();
      } else if (key == LogicalKeyboardKey.arrowLeft) {
        final origin = _sortOrigin;
        if (_canFocus(origin)) {
          origin?.requestFocus();
        } else if (_canFocus(_lastGenreFocus)) {
          _lastGenreFocus.requestFocus();
        } else if (_canFocus(_watchFocus)) {
          _watchFocus.requestFocus();
        } else {
          _focusRail();
        }
      }
    }

    return KeyEventResult.handled;
  }

  double _sortMaxWidth(BuildContext context) => MediaQuery.sizeOf(context).width / 3;

  Widget _sortButton() => Focus(canRequestFocus: false, onKeyEvent: _handleSortKey, child: _sortControls(tv: true));

  Widget _sortControls({required bool tv}) => Wrap(
    alignment: tv ? WrapAlignment.end : WrapAlignment.start,
    crossAxisAlignment: WrapCrossAlignment.center,
    spacing: AppSpacing.sm,
    runSpacing: AppSpacing.xs,
    children: [
      const Text('Фильтр'),
      AppButton(
        key: const ValueKey('catalog-sort'),
        autofocus: tv,
        focusNode: _sortFocus,
        label: catalogSortLabel(_confirmedSort),
        variant: AppButtonVariant.metadata,
        icon: const AppIcon(AppIconType.listFilter, size: 16),
        onPressed: () => unawaited(_chooseSort()),
      ),
    ],
  );

  void _reload() {
    _keepSortFocus = false;
    ref.read(favoritesControllerProvider.notifier).invalidate();
    setState(() {
      _selectedIndex = 0;
      _selectedId = null;
    });
    _bloc.add(const CatalogStarted());
  }

  void _requestMore() {
    if (AppLayoutScope.isTvOf(context)) {
      if (!_tvActive) return;
      if (_retryFocus.hasFocus) _focusContent();
      if (_bloc.state case final CatalogFailure failure when failure.isRefreshFailure) {
        refresh();

        return;
      }
      final bloc = _bloc;
      bloc.add(CatalogMoreRequested(retry: true, canStart: () => _tvActive && identical(bloc, _bloc)));

      return;
    }
    _bloc.add(const CatalogMoreRequested(retry: true));
  }

  void _selectAndOpen(AnimeSummary anime, int index) {
    setState(() {
      _selectedIndex = index;
      _selectedId = anime.id;
    });
    widget.onAnimeTap(anime);
  }

  @override
  void didUpdateWidget(covariant CatalogScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.active) _clearContinuationIntent();
    if (oldWidget.favoritesOnly != widget.favoritesOnly || oldWidget.filter?.path != widget.filter?.path) {
      _replaceCatalog();
    }
  }

  void _replaceCatalog() {
    _clearContinuationIntent();
    _returnToPoster = false;
    unawaited(_bloc.close());
    _selectedIndex = 0;
    _selectedId = null;
    _lastCardFocus = null;
    _initialFilteredLoad = true;
    _sortOrigin = null;
    _sortInteracted = false;
    _keepSortFocus = false;
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
    _startCatalog();
  }

  void _onSourceChanged() {
    final catalog = widget.favoritesOnly ? favoritesRepositoryProvider : catalogRepositoryProvider;
    final repository = widget.filter != null ? ref.read(catalogBrowseRepositoryProvider) : ref.read(catalog);
    final access = ref.read(authAccessProvider);
    if (_sourceKey != (repository, access.account, access.canUseAccount)) setState(_replaceCatalog);
  }

  @override
  void dispose() {
    _disposed.complete();
    _watchFocus.dispose();
    _favoriteFocus.dispose();
    _lastGenreFocus.dispose();
    _retryFocus.dispose();
    for (final focus in _cardFocus.values) {
      focus.dispose();
    }
    _sortFocus.dispose();
    _contentFocus.dispose();
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    unawaited(_bloc.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.filter != null) {
      ref.listen(catalogBrowseRepositoryProvider, (_, _) => _onSourceChanged());
    } else if (widget.favoritesOnly) {
      ref.listen(favoritesRepositoryProvider, (_, _) => _onSourceChanged());
    } else {
      ref.listen(catalogRepositoryProvider, (_, _) => _onSourceChanged());
    }
    ref.listen(
      authAccessProvider.select((access) => (access.account, access.canUseAccount)),
      (_, _) => _onSourceChanged(),
    );
    ref
      ..watch(favoritesControllerProvider)
      ..listen(favoritesControllerProvider, (previous, next) {
        if (widget.favoritesOnly &&
            previous?.updatingAnimeId != null &&
            next.updatingAnimeId == null &&
            next.revision != previous?.revision) {
          _bloc.add(const CatalogStarted(preserveContent: true, preservePages: true));
        }
      });

    if (!AppLayoutScope.isTvOf(context)) {
      return _mobileScreen();
    }

    return BlocProvider.value(
      value: _bloc,
      child: FocusScope(
        node: _contentFocus,
        onKeyEvent: _handleContentKey,
        child: Stack(
          fit: StackFit.expand,
          children: [
            BlocConsumer<CatalogBloc, CatalogState>(
              bloc: _bloc,
              listener: _onCatalogStateChanged,
              buildWhen: (previous, current) => previous != current,
              builder: _buildState,
            ),
            if (widget.filter != null)
              Positioned(
                top: 16,
                right: CatalogLayout.horizontalInset(MediaQuery.sizeOf(context).width),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: _sortMaxWidth(context)),
                  child: _sortButton(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
