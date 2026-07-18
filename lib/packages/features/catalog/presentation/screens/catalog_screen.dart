import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:logger/logger.dart';
import 'package:ui_kit/ui_kit.dart';

import '../../../../../app/app_config.dart';
import '../../../../../app/app_routes.dart';
import '../../domain/models/anime_summary.dart';
import '../../domain/repositories/catalog_repository.dart';
import '../bloc/catalog_bloc.dart';
import '../bloc/catalog_event.dart';
import '../bloc/catalog_state.dart';
import '../widgets/anime_card.dart';
import '../widgets/catalog_heading.dart';
import '../widgets/catalog_tail.dart';

class CatalogScreen extends StatefulWidget {
  const CatalogScreen({required this.onAnimeTap, super.key});

  final ValueChanged<AnimeSummary> onAnimeTap;

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  late final CatalogBloc _bloc;
  final ScrollController _scrollController = ScrollController();
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _bloc = CatalogBloc(repository: context.read<CatalogRepository>(), logger: context.read<Logger>())
      ..add(const CatalogStarted());
    _scrollController.addListener(_loadMoreNearEnd);
  }

  Widget _buildState(BuildContext context, CatalogState state) {
    if (state is CatalogInitial || state is CatalogLoading) {
      return const TvProgressView(label: 'Загружаем каталог…');
    }
    if (state is CatalogFailure && state.items.isEmpty) {
      return TvStateView(
        icon: Icons.cloud_off_rounded,
        title: 'Каталог недоступен',
        message: state.message,
        actionLabel: 'Попробовать снова',
        onAction: _reload,
      );
    }
    if (state.items.isEmpty) {
      return const TvStateView(
        icon: Icons.video_library_outlined,
        title: 'Каталог пуст',
        message: 'Parser не вернул ни одной карточки.',
      );
    }

    final showTail = state is CatalogReady && state.isLoadingMore || state is CatalogFailure;

    return LayoutBuilder(
      builder: (context, constraints) => CustomScrollView(
        controller: _scrollController,
        clipBehavior: Clip.none,
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.xxl, AppSpacing.lg, AppSpacing.xxl, AppSpacing.md),
            sliver: SliverToBoxAdapter(child: CatalogHeading(itemCount: state.items.length)),
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

                return AnimeCard(
                  anime: anime,
                  autofocus: index == _selectedIndex,
                  onFocusChanged: (focused) => _onCardFocusChanged(context, index, focused),
                  onTap: () => _selectAndOpen(anime, index),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  int _columnCount(double width) {
    if (width >= 1700) return 6;
    if (width >= 1180) return 5;
    if (width >= 820) return 4;

    return 3;
  }

  void _loadMoreNearEnd() {
    if (_scrollController.hasClients && _scrollController.position.extentAfter < 500 && _bloc.state.hasMore) {
      _bloc.add(const CatalogMoreRequested());
    }
  }

  void _openLogs() => context.push(AppRoutes.logViewer);

  void _onCardFocusChanged(BuildContext cardContext, int index, bool focused) {
    if (!focused) return;
    _selectedIndex = index;
    if (index > 0) {
      unawaited(
        Scrollable.ensureVisible(
          cardContext,
          alignment: 0.5,
          alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
          duration: AppMotion.standard,
          curve: Curves.easeOutCubic,
        ),
      );
    }
    final preloadDistance = _columnCount(MediaQuery.sizeOf(context).width) * 2;
    if (index >= _bloc.state.items.length - preloadDistance && _bloc.state.hasMore) {
      _bloc.add(const CatalogMoreRequested());
    }
  }

  void _reload() {
    setState(() => _selectedIndex = 0);
    _bloc.add(const CatalogStarted());
  }

  void _requestMore() => _bloc.add(const CatalogMoreRequested());

  void _selectAndOpen(AnimeSummary anime, int index) {
    setState(() => _selectedIndex = index);
    widget.onAnimeTap(anime);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_loadMoreNearEnd)
      ..dispose();
    unawaited(_bloc.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => BlocProvider.value(
    value: _bloc,
    child: Scaffold(
      appBar: AppBar(
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
          IconButton(onPressed: _reload, tooltip: 'Обновить каталог', icon: const Icon(Icons.refresh_rounded)),
          if (AppConfig.isDevFlavor)
            IconButton(onPressed: _openLogs, tooltip: 'Открыть логи', icon: const Icon(Icons.article_outlined)),
          const SizedBox(width: AppSpacing.xl),
        ],
      ),
      body: TvBackdrop(
        child: SafeArea(
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
