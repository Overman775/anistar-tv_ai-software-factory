import 'dart:async';

import 'package:app_logging/providers.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';

import '../../../auth/auth_providers.dart';
import '../../../favorites/favorites_providers.dart';
import '../../../favorites/presentation/favorite_actions_sheet.dart';
import '../../catalog_providers.dart';
import '../../domain/models/anime_summary.dart';
import '../../domain/models/catalog_filter.dart';
import '../../domain/models/catalog_sort.dart';
import '../../domain/repositories/filtered_catalog_repository.dart';
import '../bloc/catalog_bloc.dart';
import '../bloc/catalog_event.dart';
import '../bloc/catalog_state.dart';
import '../mobile/mobile_anime_card.dart';
import '../widgets/anime_card.dart';
import '../widgets/catalog_inspector.dart';
import '../widgets/catalog_layout.dart';
import '../widgets/catalog_navigation_rail.dart';
import '../widgets/catalog_skeleton.dart';
import '../widgets/catalog_sort_sheet.dart';
import '../widgets/catalog_tail.dart';

class CatalogScreen extends ConsumerStatefulWidget {
  const CatalogScreen({
    required this.onAnimeTap,
    this.onOpenLogs,
    this.onOpenGenres,
    this.onOpenNavigation,
    this.filter,
    this.onBack,
    this.onRootBack,
    this.onSignOut,
    this.accountName,
    this.onTabSelected,
    this.favoritesOnly = false,
    this.autofocusTab = false,
    this.embedded = false,
    this.genresActive = false,
    this.sectionBuilder,
    super.key,
  });

  final String? accountName;
  final VoidCallback? onOpenGenres;
  final VoidCallback? onOpenNavigation;
  final VoidCallback? onBack;
  final VoidCallback? onRootBack;
  final CatalogFilter? filter;
  final bool favoritesOnly;
  final bool autofocusTab;
  final bool embedded;
  final bool genresActive;
  final Widget Function(VoidCallback onOpenNavigation)? sectionBuilder;
  final ValueChanged<AnimeSummary> onAnimeTap;
  final VoidCallback? onOpenLogs;
  final VoidCallback? onSignOut;
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
  CatalogSort get _sort => _filteredRepository?.sort ?? defaultCatalogSort;
  final ScrollController _scrollController = ScrollController();
  final _homeTabFocus = FocusNode(debugLabel: 'Главная');
  final _genresFocus = FocusNode(debugLabel: 'Жанры');
  final _backFocus = FocusNode(debugLabel: 'Назад');
  final _favoritesTabFocus = FocusNode(debugLabel: 'Избранное');
  final _signOutFocus = FocusNode(debugLabel: 'Выйти из аккаунта');
  final _logsFocus = FocusNode(debugLabel: 'Открыть логи');
  final _contentFocus = FocusScopeNode(debugLabel: 'Каталог');
  bool _railExpanded = false;
  bool _pendingFirst = false;
  bool _initialFilteredLoad = true;
  bool _sortInteracted = false;
  bool _keepSortFocus = false;
  FocusNode? _lastCardFocus;
  int _selectedIndex = 0;
  final _inspected = ValueNotifier<AnimeSummary?>(null);

  @override
  void initState() {
    super.initState();
    _startCatalog();
    _scrollController.addListener(_loadMoreNearEnd);
  }

  void _startCatalog() {
    _filteredRepository = null;
    final filter = widget.filter;
    if (filter != null) {
      _filteredRepository = FilteredCatalogRepository(ref.read(catalogBrowseRepositoryProvider), filter);
    }
    _bloc = CatalogBloc(
      repository:
          _filteredRepository ??
          (widget.favoritesOnly ? ref.read(favoritesRepositoryProvider) : ref.read(catalogRepositoryProvider)),
      logger: ref.read(loggerProvider),
    )..add(const CatalogStarted());
  }

  void _onRailFocusChanged(bool focused) {
    if (_railExpanded != focused) {
      setState(() => _railExpanded = focused);
    }
  }

  void focusFirst() {
    _selectedIndex = 0;
    _lastCardFocus = null;
    final state = _bloc.state;
    final first = state.items.firstOrNull;
    final node = _contentFocus.traversalDescendants
        .where(
          (node) =>
              node.canRequestFocus &&
              (first != null
                  ? node.context?.findAncestorWidgetOfExactType<AnimeCard>()?.anime.id == first.id
                  : node.context?.findAncestorWidgetOfExactType<TvStateView>() != null),
        )
        .firstOrNull;
    if (node != null) {
      _pendingFirst = false;
      node.requestFocus();
    } else {
      _pendingFirst = state is CatalogInitial || state is CatalogLoading;
      _contentFocus.requestFocus();
    }
  }

  void refresh() => _bloc.add(const CatalogStarted(preserveContent: true, preservePages: true));

  void _focusContent() {
    final previous = _lastCardFocus;
    if (!widget.genresActive && previous?.context != null && previous?.canRequestFocus == true) {
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
    if (widget.embedded && widget.onOpenNavigation != null) {
      widget.onOpenNavigation?.call();

      return;
    }
    _keepSortFocus = false;
    if (widget.genresActive || widget.filter != null && widget.onOpenGenres != null) {
      _genresFocus.requestFocus();
    } else if (widget.onTabSelected == null) {
      if (widget.onBack != null) {
        _backFocus.requestFocus();
      } else if (widget.onOpenGenres != null) {
        _genresFocus.requestFocus();
      } else if (widget.onSignOut != null) {
        _signOutFocus.requestFocus();
      } else if (widget.onOpenLogs != null) {
        _logsFocus.requestFocus();
      } else {
        _focusContent();
      }
    } else {
      (widget.favoritesOnly ? _favoritesTabFocus : _homeTabFocus).requestFocus();
    }
  }

  void _onPopInvoked(bool didPop, Object? result) {
    if (didPop) {
      return;
    }
    if (_railExpanded) {
      _focusContent();
    } else if (widget.onBack == null && widget.favoritesOnly && widget.onTabSelected != null) {
      widget.onTabSelected?.call(false);
    } else if (widget.onBack == null) {
      widget.onRootBack?.call();
    }
  }

  KeyEventResult _handleHeaderKey(FocusNode node, KeyEvent event) {
    final nodes = [
      if (widget.onTabSelected != null) ...[_homeTabFocus, _favoritesTabFocus],
      if (widget.onBack != null) _backFocus,
      if (widget.onOpenGenres != null) _genresFocus,
      if (widget.onSignOut != null) _signOutFocus,
      if (widget.onOpenLogs != null) _logsFocus,
    ];
    final index = nodes.indexOf(FocusManager.instance.primaryFocus ?? node);
    if (index < 0) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    FocusNode? target;
    if (key == LogicalKeyboardKey.arrowUp || key == LogicalKeyboardKey.arrowDown) {
      final next = index + (key == LogicalKeyboardKey.arrowDown ? 1 : -1);
      target = nodes[next.clamp(0, nodes.length - 1)];
    } else if (key == LogicalKeyboardKey.arrowRight || key == LogicalKeyboardKey.escape) {
      if (event is KeyDownEvent || event is KeyRepeatEvent) {
        _focusContent();
      }

      return KeyEventResult.handled;
    } else if (key != LogicalKeyboardKey.arrowLeft) {
      return KeyEventResult.ignored;
    }
    if (event is KeyDownEvent || event is KeyRepeatEvent) {
      target?.requestFocus();
    }

    return KeyEventResult.handled;
  }

  Widget _buildState(BuildContext context, CatalogState state) {
    if (state is CatalogInitial || state is CatalogLoading) {
      return const CatalogSkeleton();
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
      // The platform branch shares this State's bloc and scroll controller.
      // ignore: avoid-returning-widgets
      return _mobileGrid(state);
    }

    final showTail = state is CatalogReady && state.isLoadingMore || state is CatalogFailure;
    final viewport = MediaQuery.sizeOf(context);
    final horizontalInset = CatalogLayout.horizontalInset(viewport.width);

    return Column(
      children: [
        ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: CatalogLayout.inspectorHeight(viewport.height, MediaQuery.textScalerOf(context).scale(16) / 16),
          ),
          child: ValueListenableBuilder<AnimeSummary?>(
            valueListenable: _inspected,
            builder: (context, selected, child) => CatalogInspector(
              anime: state.items.where((item) => item.id == selected?.id).firstOrNull ?? state.items.first,
            ),
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) => Focus(
              canRequestFocus: false,
              onKeyEvent: (_, event) => _handleCatalogKey(event, _columnCount(constraints.maxWidth)),
              child: CustomScrollView(
                controller: _scrollController,
                slivers: [
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(horizontalInset, AppSpacing.md, horizontalInset, 72),
                    sliver: SliverGrid.builder(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: _columnCount(constraints.maxWidth),
                        childAspectRatio: 0.68,
                        crossAxisSpacing: AppSpacing.lg,
                        mainAxisSpacing: AppSpacing.xl,
                      ),
                      itemCount: state.items.length + (showTail ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == state.items.length) {
                          return CatalogTail(
                            error: state is CatalogFailure ? state.message : null,
                            onRetry: _requestMore,
                          );
                        }
                        final anime = state.items[index];

                        return Builder(
                          key: ValueKey(anime.id),
                          builder: (cardContext) => AnimeCard(
                            anime: anime,
                            isFavorite: ref.read(favoritesControllerProvider).known[anime.id],
                            showFavorite: !widget.favoritesOnly && ref.watch(authAccessProvider).canUseAccount,
                            onLongPressed: () => unawaited(_favoriteActions(anime)),
                            autofocus:
                                !widget.autofocusTab && !_railExpanded && !_keepSortFocus && index == _selectedIndex,
                            onFocusChanged: (focused) =>
                                _onCardFocusChanged(cardContext, index, focused, _columnCount(constraints.maxWidth)),
                            onTap: () => _selectAndOpen(anime, index),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _refreshMobile() => _mobileRefresh ??= _performMobileRefresh().whenComplete(() => _mobileRefresh = null);

  Future<void> _performMobileRefresh() async {
    final bloc = _bloc;
    // Revision must be sampled again after the asynchronous refresh.
    // ignore: prefer-moving-to-variable
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
    // ignore: prefer-moving-to-variable
    if (state is CatalogReady && ref.read(favoritesControllerProvider).revision == revision) {
      final favorites = ref.read(favoritesControllerProvider.notifier)..invalidate();
      for (final anime in state.items) {
        favorites.observe(anime.id, anime.isFavorite);
      }
    } else if (state is CatalogFailure && state.items.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Не удалось обновить. ${state.message}')));
    }
  }

  Widget _mobileGrid(CatalogState state) => LayoutBuilder(
    builder: (context, constraints) {
      final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
      final columns = (constraints.maxWidth / (scale > 1.5 ? 220 : 160)).floor().clamp(1, 6);
      final horizontalPadding = AppLayoutScope.horizontalPaddingOf(context);
      final width = (constraints.maxWidth - horizontalPadding * 2 - (columns - 1) * 12) / columns;
      final tail = state is CatalogFailure && !state.isRefreshFailure || state is CatalogReady && state.isLoadingMore;

      return CustomScrollView(
        key: PageStorageKey(('mobile-catalog', widget.favoritesOnly, widget.filter?.path)),
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: EdgeInsets.fromLTRB(horizontalPadding, 8, horizontalPadding, 24),
            sliver: SliverGrid.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                mainAxisExtent: width / AppSizes.posterRatio,
                crossAxisSpacing: 12,
                mainAxisSpacing: 20,
              ),
              itemCount: state.items.length,
              itemBuilder: (context, index) {
                final anime = state.items[index];

                return MobileAnimeCard(
                  key: ValueKey(anime.id),
                  anime: anime,
                  isFavorite: ref.read(favoritesControllerProvider).known[anime.id],
                  showFavorite: !widget.favoritesOnly && ref.watch(authAccessProvider).canUseAccount,
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
          if (widget.embedded) SliverPadding(padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom)),
        ],
      );
    },
  );

  Widget _mobileScreen(BuildContext context) => BlocProvider.value(
    value: _bloc,
    child: Scaffold(
      backgroundColor: Colors.transparent,
      appBar: widget.embedded
          ? null
          : AppBar(
              title: Text(widget.filter?.label ?? (widget.favoritesOnly ? 'Избранное' : 'Главная')),
              leading: widget.onBack == null
                  ? null
                  : IconButton(
                      tooltip: 'Назад',
                      onPressed: widget.onBack,
                      icon: const AppIcon.fromMaterial(Icons.arrow_back),
                    ),
            ),
      body: SafeArea(
        top: !widget.embedded,
        bottom: !widget.embedded,
        child: Column(
          children: [
            if (widget.filter != null)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: AppLayoutScope.horizontalPaddingOf(context)),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => unawaited(_chooseSort()),
                    icon: const AppIcon.fromMaterial(Icons.sort),
                    label: Text(catalogSortLabel(_sort), maxLines: 2),
                  ),
                ),
              ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refreshMobile,
                child: BlocBuilder<CatalogBloc, CatalogState>(
                  bloc: _bloc,
                  buildWhen: (previous, current) => previous != current,
                  builder: (context, state) {
                    if (state.items.isNotEmpty) {
                      return _mobileGrid(state);
                    }
                    if (state is CatalogLoading || state is CatalogInitial) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    return LayoutBuilder(
                      builder: (context, constraints) => SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: Padding(
                          padding: EdgeInsets.only(bottom: widget.embedded ? MediaQuery.paddingOf(context).bottom : 0),
                          child: SizedBox(
                            height:
                                (constraints.maxHeight - (widget.embedded ? MediaQuery.paddingOf(context).bottom : 0))
                                    .clamp(0.0, double.infinity),
                            child: _buildState(context, state),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  KeyEventResult _handleCatalogKey(KeyEvent event, int columns) {
    final fromCard = FocusManager.instance.primaryFocus?.context?.findAncestorWidgetOfExactType<AnimeCard>() != null;
    if (!fromCard) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowLeft && _selectedIndex % columns == 0) {
      if (event is KeyDownEvent || event is KeyRepeatEvent) {
        _focusRail();
      }

      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp && _selectedIndex < columns && widget.filter != null) {
      if (event is KeyDownEvent || event is KeyRepeatEvent) {
        _sortFocus.requestFocus();
      }

      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp && _selectedIndex < columns ||
        key == LogicalKeyboardKey.arrowRight &&
            (_selectedIndex % columns == columns - 1 || _selectedIndex == _bloc.state.items.length - 1)) {
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  KeyEventResult _handleContentKey(FocusNode node, KeyEvent event) {
    if (widget.filter != null && _bloc.state.items.isEmpty && event.logicalKey == LogicalKeyboardKey.arrowUp) {
      if (event is KeyDownEvent || event is KeyRepeatEvent) {
        _sortFocus.requestFocus();
      }

      return KeyEventResult.handled;
    }
    final fromCard = FocusManager.instance.primaryFocus?.context?.findAncestorWidgetOfExactType<AnimeCard>() != null;
    if (fromCard || event.logicalKey != LogicalKeyboardKey.arrowLeft) {
      return KeyEventResult.ignored;
    }
    if (event is KeyDownEvent) {
      _focusRail();
    }

    return KeyEventResult.handled;
  }

  Future<void> _favoriteActions(AnimeSummary anime) async {
    await showFavoriteActions(context, animeId: anime.id, slug: anime.slug, title: anime.title);
    if (mounted && AppLayoutScope.isTvOf(context) && _lastCardFocus?.context == null) {
      _focusRail();
    }
  }

  void _onCatalogStateChanged(BuildContext context, CatalogState state) {
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
    if (!AppLayoutScope.isTvOf(context) || widget.genresActive) {
      return;
    }
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
        (!widget.embedded || _contentFocus.hasFocus) &&
        ModalRoute.of(context)?.isCurrent == true) {
      _focusRail();
    }
  }

  int _columnCount(double width) => CatalogLayout.columnCount(width);

  void _loadMoreNearEnd() {
    if (!widget.genresActive &&
        _scrollController.hasClients &&
        _scrollController.position.extentAfter < 500 &&
        _canPreload) {
      _bloc.add(const CatalogMoreRequested());
    }
  }

  bool get _canPreload {
    final state = _bloc.state;

    return state.hasMore && (state is CatalogReady || state is CatalogFailure && state.isRefreshFailure);
  }

  void _onCardFocusChanged(BuildContext cardContext, int index, bool focused, int columns) {
    if (!focused) {
      return;
    }
    final state = _bloc.state;
    _keepSortFocus = false;
    _selectedIndex = index;
    _inspected.value = state.items.elementAtOrNull(index);
    _lastCardFocus = FocusManager.instance.primaryFocus;
    if (index == 0 && _scrollController.hasClients) {
      unawaited(
        _scrollController.animateTo(
          0,
          duration: AppMotion.durationOf(context, AppMotion.standard),
          curve: Curves.easeOutCubic,
        ),
      );
    } else {
      unawaited(
        Scrollable.ensureVisible(
          cardContext,
          alignment: 0.5,
          duration: AppMotion.durationOf(context, AppMotion.standard),
          curve: Curves.easeOutCubic,
        ),
      );
    }
    final preloadDistance = columns * 2;
    if (index >= state.items.length - preloadDistance && _canPreload) {
      _bloc.add(const CatalogMoreRequested());
    }
  }

  Future<void> _chooseSort() async {
    _sortInteracted = true;
    final selected = await showAppActionSheet<CatalogSort>(
      context: context,
      builder: (_) => CatalogSortSheet(selected: _sort),
    );
    if (!mounted) {
      return;
    }
    if (AppLayoutScope.isTvOf(context)) {
      _sortFocus.requestFocus();
    }
    if (selected == null || selected == _sort) {
      return;
    }
    setState(() {
      _keepSortFocus = true;
      final current = _filteredRepository;
      if (current != null) {
        _filteredRepository = FilteredCatalogRepository(current.repository, current.filter, sort: selected);
      }
      _selectedIndex = 0;
      _lastCardFocus = null;
    });
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
    _bloc.add(CatalogStarted(repository: _filteredRepository));
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
        _focusRail();
      }
    }

    return KeyEventResult.handled;
  }

  Widget _sortButton() => Focus(
    canRequestFocus: false,
    onKeyEvent: _handleSortKey,
    child: TvFocusable(
      key: const ValueKey('catalog-sort'),
      autofocus: true,
      focusNode: _sortFocus,
      semanticLabel: 'Сортировка: ${catalogSortLabel(_sort)}',
      onPressed: () => unawaited(_chooseSort()),
      builder: (context, focused) => AppFocusBorder(
        focused: focused,
        child: AnimatedContainer(
          duration: AppMotion.durationOf(context, AppMotion.fast),
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: AppFocusStyle.decoration(
            focused: focused,
            restingColor: AppPalette.surfaceElevated,
          ).copyWith(border: const Border()),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const AppIcon.fromMaterial(Icons.sort, color: AppPalette.textPrimary),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  catalogSortLabel(_sort),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppPalette.textPrimary),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  void _reload() {
    _keepSortFocus = false;
    ref.read(favoritesControllerProvider.notifier).invalidate();
    setState(() => _selectedIndex = 0);
    _bloc.add(const CatalogStarted());
  }

  void _requestMore() => _bloc.add(const CatalogMoreRequested(retry: true));

  void _selectAndOpen(AnimeSummary anime, int index) {
    setState(() => _selectedIndex = index);
    widget.onAnimeTap(anime);
  }

  @override
  void didUpdateWidget(covariant CatalogScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.favoritesOnly != widget.favoritesOnly || oldWidget.filter?.path != widget.filter?.path) {
      unawaited(_bloc.close());
      _selectedIndex = 0;
      _lastCardFocus = null;
      _initialFilteredLoad = true;
      _sortInteracted = false;
      _keepSortFocus = false;
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
      _startCatalog();
      if (widget.autofocusTab) {
        _focusRail();
      }
    }
  }

  @override
  void dispose() {
    _disposed.complete();
    _inspected.dispose();
    _sortFocus.dispose();
    _contentFocus.dispose();
    _homeTabFocus.dispose();
    _genresFocus.dispose();
    _backFocus.dispose();
    _favoritesTabFocus.dispose();
    _signOutFocus.dispose();
    _logsFocus.dispose();
    _scrollController
      ..removeListener(_loadMoreNearEnd)
      ..dispose();
    unawaited(_bloc.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref
      ..watch(favoritesControllerProvider)
      ..listen(favoritesControllerProvider, (previous, next) {
        if (widget.favoritesOnly &&
            previous?.updatingAnimeId != null &&
            next.updatingAnimeId == null &&
            next.revision != previous?.revision) {
          _bloc.add(const CatalogStarted());
        }
      });

    if (!AppLayoutScope.isTvOf(context)) {
      // Both layouts retain the same catalog State, bloc and navigation handlers.
      // ignore: avoid-returning-widgets
      return _mobileScreen(context);
    }

    if (widget.embedded) {
      return BlocProvider.value(
        value: _bloc,
        child: FocusScope(
          node: _contentFocus,
          onKeyEvent: _handleContentKey,
          child: Column(
            children: [
              if (widget.filter case final filter?)
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final title = Text(
                        filter.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.headlineSmall,
                      );
                      final sort = Builder(builder: (_) => _sortButton());

                      return constraints.maxWidth < 600
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [title, const SizedBox(height: 8), sort],
                            )
                          : Row(
                              children: [
                                Expanded(child: title),
                                const SizedBox(width: 16),
                                Flexible(child: sort),
                              ],
                            );
                    },
                  ),
                ),
              Expanded(
                child: BlocConsumer<CatalogBloc, CatalogState>(
                  bloc: _bloc,
                  listener: _onCatalogStateChanged,
                  buildWhen: (previous, current) => previous != current,
                  builder: _buildState,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final items = <CatalogNavigationItem>[
      if (widget.onTabSelected != null) ...[
        (
          key: const ValueKey('catalog-tab-false'),
          icon: Icons.home_outlined,
          label: 'Главная',
          focusNode: _homeTabFocus,
          onPressed: () => widget.onTabSelected?.call(false),
          selected: widget.filter == null && !widget.genresActive && !widget.favoritesOnly,
          autofocus: widget.autofocusTab && !widget.genresActive && !widget.favoritesOnly,
        ),
        (
          key: const ValueKey('catalog-tab-true'),
          icon: Icons.favorite_border_rounded,
          label: 'Избранное',
          focusNode: _favoritesTabFocus,
          onPressed: () => widget.onTabSelected?.call(true),
          selected: widget.filter == null && !widget.genresActive && widget.favoritesOnly,
          autofocus: widget.autofocusTab && !widget.genresActive && widget.favoritesOnly,
        ),
      ],
      if (widget.onBack case final onBack?)
        (
          key: const ValueKey('catalog-back'),
          icon: Icons.arrow_back,
          label: 'Назад',
          focusNode: _backFocus,
          onPressed: onBack,
          selected: false,
          autofocus: false,
        ),
      if (widget.onOpenGenres case final onOpenGenres?)
        (
          key: const ValueKey('catalog-genres'),
          icon: Icons.category_outlined,
          label: 'Жанры',
          focusNode: _genresFocus,
          onPressed: onOpenGenres,
          selected: widget.genresActive || widget.filter != null,
          autofocus: false,
        ),
      if (widget.onSignOut case final onSignOut?)
        (
          key: const ValueKey('catalog-account'),
          icon: Icons.account_circle_outlined,
          label: 'Выйти из аккаунта',
          focusNode: _signOutFocus,
          onPressed: onSignOut,
          selected: false,
          autofocus: false,
        ),
      if (widget.onOpenLogs case final onOpenLogs?)
        (
          key: const ValueKey('catalog-logs'),
          icon: Icons.article_outlined,
          label: 'Открыть логи',
          focusNode: _logsFocus,
          onPressed: onOpenLogs,
          selected: false,
          autofocus: false,
        ),
    ];

    return BlocProvider.value(
      value: _bloc,
      child: PopScope(
        canPop:
            !_railExpanded &&
            !(widget.onBack == null &&
                (widget.onRootBack != null || widget.favoritesOnly && widget.onTabSelected != null)),
        onPopInvokedWithResult: _onPopInvoked,
        child: TvBackdrop(
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: SafeArea(
              child: Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: CatalogNavigationRail.collapsedWidth),
                    child: Column(
                      children: [
                        if (widget.filter case final filter?)
                          Padding(
                            padding: const EdgeInsets.all(AppSpacing.lg),
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final title = Text(
                                  filter.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.headlineSmall,
                                );

                                return constraints.maxWidth < 600
                                    ? Column(
                                        crossAxisAlignment: CrossAxisAlignment.stretch,
                                        children: [title, const SizedBox(height: 8), _sortButton()],
                                      )
                                    : Row(
                                        children: [
                                          Expanded(child: title),
                                          const SizedBox(width: 16),
                                          Flexible(child: _sortButton()),
                                        ],
                                      );
                              },
                            ),
                          ),
                        Expanded(
                          child: FocusScope(
                            node: _contentFocus,
                            onKeyEvent: _handleContentKey,
                            child: TweenAnimationBuilder<double>(
                              key: ValueKey((widget.favoritesOnly, widget.filter?.path)),
                              tween: Tween(begin: 0, end: 1),
                              duration: AppMotion.durationOf(context, AppMotion.fast),
                              curve: AppMotion.enterCurve,
                              builder: (context, value, child) => Opacity(opacity: value, child: child),
                              child: IndexedStack(
                                index: widget.genresActive ? 1 : 0,
                                children: [
                                  HeroMode(
                                    enabled: !widget.genresActive,
                                    child: TickerMode(
                                      enabled: !widget.genresActive,
                                      child: ExcludeFocus(
                                        excluding: widget.genresActive,
                                        child: BlocConsumer<CatalogBloc, CatalogState>(
                                          bloc: _bloc,
                                          listener: _onCatalogStateChanged,
                                          buildWhen: (previous, current) => previous != current,
                                          builder: _buildState,
                                        ),
                                      ),
                                    ),
                                  ),
                                  ExcludeFocus(
                                    excluding: !widget.genresActive,
                                    child: TickerMode(
                                      enabled: widget.genresActive,
                                      child: widget.sectionBuilder?.call(_focusRail) ?? const SizedBox.shrink(),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned.fill(
                    left: CatalogNavigationRail.collapsedWidth,
                    child: IgnorePointer(
                      ignoring: !_railExpanded,
                      child: AnimatedOpacity(
                        opacity: _railExpanded ? 1 : 0,
                        duration: AppMotion.durationOf(context, AppMotion.standard),
                        child: GestureDetector(
                          onTap: _focusContent,
                          child: const ColoredBox(color: Color(0x66000000)),
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    right: null,
                    child: Focus(
                      canRequestFocus: false,
                      onFocusChange: _onRailFocusChanged,
                      onKeyEvent: _handleHeaderKey,
                      child: CatalogNavigationRail(
                        expanded: _railExpanded,
                        items: items,
                        accountName: widget.accountName,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
