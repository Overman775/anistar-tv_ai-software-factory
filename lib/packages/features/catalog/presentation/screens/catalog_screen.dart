import 'dart:async';

import 'package:app_logging/providers.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';

import '../../../favorites/favorites_providers.dart';
import '../../../favorites/presentation/favorite_actions_dialog.dart';
import '../../catalog_providers.dart';
import '../../domain/models/anime_summary.dart';
import '../bloc/catalog_bloc.dart';
import '../bloc/catalog_event.dart';
import '../bloc/catalog_state.dart';
import '../widgets/anime_card.dart';
import '../widgets/catalog_heading.dart';
import '../widgets/catalog_skeleton.dart';
import '../widgets/catalog_tabs.dart';
import '../widgets/catalog_tail.dart';

class CatalogScreen extends ConsumerStatefulWidget {
  const CatalogScreen({
    required this.onAnimeTap,
    this.onOpenLogs,
    this.onSignOut,
    this.onTabSelected,
    this.favoritesOnly = false,
    this.autofocusTab = false,
    super.key,
  });

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
              padding: const EdgeInsets.fromLTRB(AppSpacing.xxl, AppSpacing.md, AppSpacing.xxl, AppSpacing.sm),
              sliver: SliverToBoxAdapter(
                child: CatalogHeading(
                  itemCount: state.items.length,
                  favoritesOnly: widget.favoritesOnly,
                  showFavoriteHint: widget.onTabSelected != null,
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.xxl, AppSpacing.sm, AppSpacing.xxl, 72),
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
                      autofocus: index == _selectedIndex,
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
    if (widget.onTabSelected == null ||
        !fromCard ||
        _selectedIndex >= columns ||
        event.logicalKey != LogicalKeyboardKey.arrowUp) {
      return KeyEventResult.ignored;
    }
    if (event is KeyDownEvent) {
      (widget.favoritesOnly ? _favoritesTabFocus : _homeTabFocus).requestFocus();
    }

    return KeyEventResult.handled;
  }

  Future<void> _favoriteActions(AnimeSummary anime) async {
    await showFavoriteActions(context, animeId: anime.id, slug: anime.slug, title: anime.title);
  }

  int _columnCount(double width) {
    if (width >= 1700) {
      return 6;
    }
    if (width >= 1180) {
      return 5;
    }
    if (width >= 820) {
      return 4;
    }

    return 3;
  }

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
    if (index == 0 && _scrollController.hasClients) {
      unawaited(_scrollController.animateTo(0, duration: AppMotion.standard, curve: Curves.easeOutCubic));
    } else {
      unawaited(
        Scrollable.ensureVisible(cardContext, alignment: 0.5, duration: AppMotion.standard, curve: Curves.easeOutCubic),
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
    _homeTabFocus.dispose();
    _favoritesTabFocus.dispose();
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

    return BlocProvider.value(
      value: _bloc,
      child: TvBackdrop(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
            flexibleSpace: const TvHeaderSurface(),
            bottom: switch (widget.onTabSelected) {
              final onSelected? => CatalogTabs(
                favoritesOnly: widget.favoritesOnly,
                autofocus: widget.autofocusTab,
                homeFocusNode: _homeTabFocus,
                favoritesFocusNode: _favoritesTabFocus,
                onSelected: onSelected,
              ),
              null => null,
            },
            toolbarHeight: 88,
            titleSpacing: AppSpacing.xxl,
            title: Row(
              children: [
                Icon(Icons.live_tv_rounded, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: AppSpacing.sm),
                const Text('AniStar TV'),
              ],
            ),
            actions: [
              if (widget.onSignOut != null)
                IconButton(onPressed: widget.onSignOut, tooltip: 'Выйти из аккаунта', icon: const Icon(Icons.logout)),
              IconButton(onPressed: _reload, tooltip: 'Обновить каталог', icon: const Icon(Icons.refresh_rounded)),
              if (widget.onOpenLogs != null)
                IconButton(
                  onPressed: widget.onOpenLogs,
                  tooltip: 'Открыть логи',
                  icon: const Icon(Icons.article_outlined),
                ),
              const SizedBox(width: AppSpacing.xl),
            ],
          ),
          body: SafeArea(
            top: false,
            minimum: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: BlocBuilder<CatalogBloc, CatalogState>(
              buildWhen: (previous, current) => previous != current,
              builder: _buildState,
            ),
          ),
        ),
      ),
    );
  }
}
