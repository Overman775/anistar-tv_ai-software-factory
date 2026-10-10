import 'dart:async';

import 'package:app_logging/providers.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';

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
import '../widgets/anime_card.dart';
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
    this.filter,
    this.onBack,
    this.onSignOut,
    this.accountName,
    this.onTabSelected,
    this.favoritesOnly = false,
    this.autofocusTab = false,
    super.key,
  });

  final String? accountName;
  final VoidCallback? onOpenGenres;
  final VoidCallback? onBack;
  final CatalogFilter? filter;
  final bool favoritesOnly;
  final bool autofocusTab;
  final ValueChanged<AnimeSummary> onAnimeTap;
  final VoidCallback? onOpenLogs;
  final VoidCallback? onSignOut;
  final ValueChanged<bool>? onTabSelected;

  @override
  ConsumerState<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends ConsumerState<CatalogScreen> {
  late final CatalogBloc _bloc;
  FilteredCatalogRepository? _filteredRepository;
  final _sortFocus = FocusNode(debugLabel: 'Сортировка');
  CatalogSort get _sort => _filteredRepository?.sort ?? defaultCatalogSort;
  final ScrollController _scrollController = ScrollController();
  final _homeTabFocus = FocusNode(debugLabel: 'Главная');
  final _genresFocus = FocusNode(debugLabel: 'Жанры');
  final _backFocus = FocusNode(debugLabel: 'Назад');
  final _favoritesTabFocus = FocusNode(debugLabel: 'Избранное');
  final _signOutFocus = FocusNode(debugLabel: 'Выйти из аккаунта');
  final _refreshFocus = FocusNode(debugLabel: 'Обновить каталог');
  final _logsFocus = FocusNode(debugLabel: 'Открыть логи');
  final _contentFocus = FocusScopeNode(debugLabel: 'Каталог');
  bool _railExpanded = false;
  bool _initialFilteredLoad = true;
  bool _sortInteracted = false;
  bool _keepSortFocus = false;
  FocusNode? _lastCardFocus;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
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
    _scrollController.addListener(_loadMoreNearEnd);
  }

  void _onRailFocusChanged(bool focused) {
    if (_railExpanded != focused) {
      setState(() => _railExpanded = focused);
    }
  }

  void _focusContent() {
    final previous = _lastCardFocus;
    if (previous?.context != null && previous?.canRequestFocus == true) {
      previous?.requestFocus();
    } else {
      (_contentFocus.traversalDescendants.where((node) => node.canRequestFocus && node.context != null).firstOrNull ??
              (widget.filter != null ? _sortFocus : _contentFocus))
          .requestFocus();
    }
  }

  void _focusRail() {
    _keepSortFocus = false;
    if (widget.onTabSelected == null) {
      (widget.onBack != null ? _backFocus : _refreshFocus).requestFocus();
    } else {
      (widget.favoritesOnly ? _favoritesTabFocus : _homeTabFocus).requestFocus();
    }
  }

  void _onPopInvoked(bool didPop, Object? result) {
    if (!didPop) {
      _focusContent();
    }
  }

  KeyEventResult _handleHeaderKey(FocusNode node, KeyEvent event) {
    final nodes = [
      if (widget.onTabSelected != null) ...[_homeTabFocus, _favoritesTabFocus],
      if (widget.onBack != null) _backFocus,
      if (widget.onOpenGenres != null) _genresFocus,
      if (widget.onSignOut != null) _signOutFocus,
      _refreshFocus,
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
        icon: widget.favoritesOnly ? Icons.star_border_rounded : Icons.video_library_outlined,
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

    final showTail = state is CatalogReady && state.isLoadingMore || state is CatalogFailure;

    return LayoutBuilder(
      builder: (context, constraints) => Focus(
        canRequestFocus: false,
        onKeyEvent: (_, event) => _handleCatalogKey(event, _columnCount(constraints.maxWidth)),
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, 72),
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
                    return CatalogTail(error: state is CatalogFailure ? state.message : null, onRetry: _requestMore);
                  }
                  final anime = state.items[index];

                  return Builder(
                    key: ValueKey(anime.id),
                    builder: (cardContext) => AnimeCard(
                      anime: anime,
                      isFavorite: ref.read(favoritesControllerProvider).known[anime.id],
                      onLongPressed: () => unawaited(_favoriteActions(anime)),
                      autofocus: !widget.autofocusTab && !_railExpanded && !_keepSortFocus && index == _selectedIndex,
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
    );
  }

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
    if (mounted && _lastCardFocus?.context == null) {
      _focusRail();
    }
  }

  void _onCatalogStateChanged(BuildContext context, CatalogState state) {
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
    if (state is CatalogReady && state.items.isEmpty && ModalRoute.of(context)?.isCurrent == true) {
      _focusRail();
    }
  }

  int _columnCount(double width) => CatalogLayout.columnCount(width);

  void _loadMoreNearEnd() {
    if (_scrollController.hasClients && _scrollController.position.extentAfter < 500 && _canPreload) {
      _bloc.add(const CatalogMoreRequested());
    }
  }

  bool get _canPreload => _bloc.state is CatalogReady && _bloc.state.hasMore;

  void _onCardFocusChanged(BuildContext cardContext, int index, bool focused, int columns) {
    if (!focused) {
      return;
    }
    _keepSortFocus = false;
    _selectedIndex = index;
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
    if (index >= _bloc.state.items.length - preloadDistance && _canPreload) {
      _bloc.add(const CatalogMoreRequested());
    }
  }

  Future<void> _chooseSort() async {
    _sortInteracted = true;
    final selected = await showTvSideSheet<CatalogSort>(
      context: context,
      builder: (_) => CatalogSortSheet(selected: _sort),
    );
    if (!mounted) {
      return;
    }
    _sortFocus.requestFocus();
    if (selected == null || selected == _sort) {
      return;
    }
    setState(() {
      _keepSortFocus = true;
      _filteredRepository?.sort = selected;
      _selectedIndex = 0;
      _lastCardFocus = null;
    });
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
    _bloc.add(const CatalogStarted());
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
      builder: (context, focused) => AnimatedContainer(
        duration: AppMotion.durationOf(context, AppMotion.fast),
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: AppFocusStyle.decoration(focused: focused, restingColor: AppPalette.surfaceElevated),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.sort, color: AppPalette.textPrimary),
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
  void dispose() {
    _sortFocus.dispose();
    _contentFocus.dispose();
    _homeTabFocus.dispose();
    _genresFocus.dispose();
    _backFocus.dispose();
    _favoritesTabFocus.dispose();
    _signOutFocus.dispose();
    _refreshFocus.dispose();
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

    final items = <CatalogNavigationItem>[
      if (widget.onTabSelected != null) ...[
        (
          key: const ValueKey('catalog-tab-false'),
          icon: Icons.home_outlined,
          label: 'Главная',
          focusNode: _homeTabFocus,
          onPressed: () => widget.onTabSelected?.call(false),
          selected: !widget.favoritesOnly,
          autofocus: widget.autofocusTab && !widget.favoritesOnly,
        ),
        (
          key: const ValueKey('catalog-tab-true'),
          icon: Icons.star_border_rounded,
          label: 'Избранное',
          focusNode: _favoritesTabFocus,
          onPressed: () => widget.onTabSelected?.call(true),
          selected: widget.favoritesOnly,
          autofocus: widget.autofocusTab && widget.favoritesOnly,
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
          selected: widget.filter != null,
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
      (
        key: const ValueKey('catalog-refresh'),
        icon: Icons.refresh_rounded,
        label: 'Обновить каталог',
        focusNode: _refreshFocus,
        onPressed: _reload,
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
        canPop: !_railExpanded,
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
                          )
                        else
                          const SizedBox(height: 32),
                        Expanded(
                          child: FocusScope(
                            node: _contentFocus,
                            onKeyEvent: _handleContentKey,
                            child: BlocConsumer<CatalogBloc, CatalogState>(
                              listener: _onCatalogStateChanged,
                              buildWhen: (previous, current) => previous != current,
                              builder: _buildState,
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
