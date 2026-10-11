import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';

import '../../../catalog/domain/models/anime_summary.dart';
import '../../../catalog/domain/models/catalog_filter.dart';
import '../../../catalog/presentation/screens/catalog_screen.dart';
import '../../../catalog/presentation/screens/genres_screen.dart';

/// Root destinations keep their controllers and scroll positions across switches.
class MobileHomeShell extends StatefulWidget {
  const MobileHomeShell({
    required this.onAnimeTap,
    this.onGenreSelected,
    this.onOpenGenres,
    this.accountName,
    this.onSignOut,
    this.onOpenLogs,
    super.key,
  });

  final ValueChanged<AnimeSummary> onAnimeTap;
  final ValueChanged<CatalogFilter>? onGenreSelected;
  final VoidCallback? onOpenGenres;
  final String? accountName;
  final VoidCallback? onSignOut;
  final VoidCallback? onOpenLogs;

  @override
  State<MobileHomeShell> createState() => _MobileHomeShellState();
}

class _MobileHomeShellState extends State<MobileHomeShell> {
  int _selected = 0;
  final _visited = <int>{0};
  bool _headerVisible = true;

  void _select(int index) => setState(() {
    _selected = index;
    _visited.add(index);
    _headerVisible = true;
  });

  bool _onScroll(ScrollNotification notification) {
    // Only the active destination's primary vertical list owns this chrome.
    // Sheets, nested lists and horizontal gestures keep their own behavior.
    if (notification.depth != 0 ||
        notification.metrics.axis != Axis.vertical ||
        ModalRoute.of(context)?.isCurrent != true ||
        MediaQuery.accessibleNavigationOf(context)) {
      return false;
    }
    final metrics = notification.metrics;
    final delta = notification is ScrollUpdateNotification ? notification.scrollDelta : null;
    // A barely scrollable list should not oscillate between two viewport sizes.
    final minimumExtent = _headerVisible ? kToolbarHeight : 0;
    if (metrics.maxScrollExtent <= minimumExtent || metrics.pixels <= metrics.minScrollExtent) {
      _showHeader(true);
    } else if (delta != null && delta != 0) {
      _showHeader(delta < 0);
    } else if (notification is UserScrollNotification && notification.direction != ScrollDirection.idle) {
      _showHeader(notification.direction == ScrollDirection.forward);
    }

    return false;
  }

  void _showHeader(bool visible) {
    if (_headerVisible != visible) {
      setState(() => _headerVisible = visible);
    }
  }

  Future<void> _account() => showAppActionSheet<void>(
    context: context,
    builder: (sheetContext) => AppActionSheet(
      title: widget.accountName ?? 'Аккаунт',
      mobileHeightFactor: MediaQuery.sizeOf(sheetContext).height < 500 ? 0.8 : 0.35,
      child: ListView(
        children: [
          if (widget.onOpenLogs != null)
            ListTile(
              leading: const Icon(Icons.article_outlined),
              title: const Text('Открыть логи'),
              onTap: () => _closeAccount(sheetContext, widget.onOpenLogs),
            ),
          if (widget.onSignOut != null)
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Выйти из аккаунта'),
              onTap: () => _closeAccount(sheetContext, widget.onSignOut),
            ),
        ],
      ),
    ),
  );

  void _closeAccount(BuildContext sheetContext, VoidCallback? action) {
    Navigator.of(sheetContext).pop();
    action?.call();
  }

  void _handleBack(bool didPop, Object? _) {
    if (!didPop && _selected != 0) {
      _select(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    const labels = ['Главная', 'Избранное', 'Жанры'];

    return PopScope(
      canPop: _selected == 0,
      onPopInvokedWithResult: _handleBack,
      child: Scaffold(
        extendBody: true,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(end: _headerVisible || MediaQuery.accessibleNavigationOf(context) ? 1 : 0),
                duration: AppMotion.durationOf(context, AppMotion.fast),
                curve: AppMotion.enterCurve,
                builder: (context, value, child) => ClipRect(
                  child: Align(alignment: Alignment.topCenter, heightFactor: value, child: child),
                ),
                child: ExcludeFocus(
                  excluding: !_headerVisible && !MediaQuery.accessibleNavigationOf(context),
                  child: ExcludeSemantics(
                    excluding: !_headerVisible && !MediaQuery.accessibleNavigationOf(context),
                    child: IgnorePointer(
                      ignoring: !_headerVisible && !MediaQuery.accessibleNavigationOf(context),
                      child: SizedBox(
                        height: kToolbarHeight,
                        child: AppBar(
                          key: const ValueKey('mobile-header'),
                          primary: false,
                          title: Text(labels[_selected]),
                          automaticallyImplyLeading: false,
                          actions: [
                            IconButton(
                              key: const ValueKey('mobile-account'),
                              tooltip: widget.accountName == null ? 'Аккаунт' : 'Аккаунт: ${widget.accountName}',
                              onPressed: () => unawaited(_account()),
                              icon: const Icon(Icons.account_circle_outlined),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: IndexedStack(
                  index: _selected,
                  children: List.generate(
                    3,
                    (index) => NotificationListener<ScrollNotification>(
                      onNotification: (notification) => index == _selected && _onScroll(notification),
                      child: HeroMode(
                        enabled: index == _selected,
                        child: TickerMode(
                          enabled: index == _selected,
                          child: !_visited.contains(index)
                              ? const SizedBox.shrink()
                              : switch (index) {
                                  2 => GenresScreen(
                                    embedded: true,
                                    onSelected: widget.onGenreSelected ?? (_) => widget.onOpenGenres?.call(),
                                  ),
                                  _ => CatalogScreen(
                                    key: ValueKey('mobile-tab-$index'),
                                    embedded: true,
                                    favoritesOnly: index == 1,
                                    onAnimeTap: widget.onAnimeTap,
                                    onTabSelected: (favorite) => _select(favorite ? 1 : 0),
                                  ),
                                },
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: ClipRect(
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0x8C24183D), Color(0x730D1220)],
                ),
                border: Border(top: BorderSide(color: Color(0x267C3AED))),
              ),
              child: NavigationBar(
                key: const ValueKey('mobile-navigation'),
                backgroundColor: Colors.transparent,
                surfaceTintColor: Colors.transparent,
                elevation: 0,
                height: MediaQuery.textScalerOf(context).scale(12) * 2 + 56,
                selectedIndex: _selected,
                onDestinationSelected: _select,
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.home_outlined),
                    selectedIcon: Icon(Icons.home),
                    label: 'Главная',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.star_border_rounded),
                    selectedIcon: Icon(Icons.star_rounded),
                    label: 'Избранное',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.category_outlined),
                    selectedIcon: Icon(Icons.category),
                    label: 'Жанры',
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
