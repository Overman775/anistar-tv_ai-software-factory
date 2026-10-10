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
import '../bloc/catalog_bloc.dart';
import '../bloc/catalog_event.dart';
import '../bloc/catalog_state.dart';
import '../widgets/anime_card.dart';
import '../widgets/catalog_layout.dart';
import '../widgets/catalog_navigation_rail.dart';
import '../widgets/catalog_skeleton.dart';
import '../widgets/catalog_tail.dart';

class CatalogScreen extends ConsumerStatefulWidget {
  const CatalogScreen({
    required this.onAnimeTap,
    this.onOpenLogs,
    this.onSignOut,
    this.accountName,
    this.onTabSelected,
    this.favoritesOnly = false,
    this.autofocusTab = false,
    super.key,
  });

  final String? accountName;
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
  final ScrollController _scrollController = ScrollController();
  final _homeTabFocus = FocusNode(debugLabel: 'Главная');
  final _favoritesTabFocus = FocusNode(debugLabel: 'Избранное');
  final _signOutFocus = FocusNode(debugLabel: 'Выйти из аккаунта');
  final _refreshFocus = FocusNode(debugLabel: 'Обновить каталог');
  final _logsFocus = FocusNode(debugLabel: 'Открыть логи');
  final _contentFocus = FocusScopeNode(debugLabel: 'Каталог');
  bool _railExpanded = false;
  FocusNode? _lastCardFocus;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _bloc = CatalogBloc(
      repository: widget.favoritesOnly ? ref.read(favoritesRepositoryProvider) : ref.read(catalogRepositoryProvider),
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
      (_contentFocus.traversalDescendants.firstOrNull ?? _contentFocus).requestFocus();
    }
  }

  void _focusRail() {
    if (widget.onTabSelected == null) {
      _refreshFocus.requestFocus();
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
      if (event is KeyDownEvent) {
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
                      autofocus: !widget.autofocusTab && !_railExpanded && index == _selectedIndex,
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
    if (key == LogicalKeyboardKey.arrowUp && _selectedIndex < columns ||
        key == LogicalKeyboardKey.arrowRight &&
            (_selectedIndex % columns == columns - 1 || _selectedIndex == _bloc.state.items.length - 1)) {
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  KeyEventResult _handleContentKey(FocusNode node, KeyEvent event) {
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

  void _reload() {
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
    _contentFocus.dispose();
    _homeTabFocus.dispose();
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
