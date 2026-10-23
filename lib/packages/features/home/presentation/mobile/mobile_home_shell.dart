import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';

import '../../../catalog/domain/models/anime_summary.dart';
import '../../../catalog/domain/models/catalog_filter.dart';
import '../../../catalog/presentation/screens/catalog_screen.dart';
import '../../../catalog/presentation/screens/genres_screen.dart';
import '../../../common/presentation/widgets/account_identity.dart';
import '../../../search/presentation/search_screen.dart';
import '../home_destination.dart';

/// Root destinations keep their controllers and scroll positions across switches.
class MobileHomeShell extends StatefulWidget {
  const MobileHomeShell({
    required this.onAnimeTap,
    this.onGenreSelected,
    this.onOpenGenres,
    this.accountName,
    this.accountImageUrl,
    this.onSignOut,
    this.onSignIn,
    this.root = false,
    this.onOpenLogs,
    this.onRootBack,
    this.destination = HomeDestination.home,
    this.onDestinationSelected,
    this.content,
    this.contextTitle,
    this.onBack,
    super.key,
  });

  final ValueChanged<AnimeSummary> onAnimeTap;
  final ValueChanged<CatalogFilter>? onGenreSelected;
  final VoidCallback? onOpenGenres;
  final String? accountName;
  final String? accountImageUrl;
  final VoidCallback? onSignOut;
  final VoidCallback? onSignIn;
  final bool root;
  final VoidCallback? onOpenLogs;
  final VoidCallback? onRootBack;
  final HomeDestination destination;
  final ValueChanged<HomeDestination>? onDestinationSelected;
  final Widget? content;
  final String? contextTitle;
  final VoidCallback? onBack;

  @override
  State<MobileHomeShell> createState() => _MobileHomeShellState();
}

class _MobileHomeShellState extends State<MobileHomeShell> {
  late int _selected;
  final _visited = <int>{};
  bool _headerVisible = true;
  bool _accountOpen = false;

  @override
  void initState() {
    super.initState();
    _selected = widget.destination.index;
    _visited.add(_selected);
  }

  List<HomeDestination> get _destinations => homeDestinations(account: widget.onSignIn == null);

  void _select(int index) => _selectDestination(_destinations[index]);

  void _selectDestination(HomeDestination destination) {
    final index = destination.index;
    final onSelected = widget.onDestinationSelected;
    if (onSelected != null) {
      onSelected(destination);

      return;
    }
    setState(() {
      _selected = index;
      _visited.add(index);
      _headerVisible = true;
    });
  }

  bool _onScroll(ScrollNotification notification) {
    // Only the active destination's primary vertical list owns this chrome.
    // Sheets, nested lists and horizontal gestures keep their own behavior.
    if (notification.depth != 0 || notification.metrics.axis != Axis.vertical) {
      return false;
    }
    if (ModalRoute.of(context)?.isCurrent != true ||
        AppMotion.reducedOf(context) ||
        MediaQuery.viewInsetsOf(context).bottom > 0 ||
        _accountOpen) {
      _showHeader(true);

      return false;
    }
    final metrics = notification.metrics;
    final delta = notification is ScrollUpdateNotification ? notification.scrollDelta : null;
    // A barely scrollable list should not oscillate between two viewport sizes.
    final minimumExtent = _headerVisible ? _headerHeight(context) : 0;
    if (metrics.maxScrollExtent <= minimumExtent || metrics.pixels <= metrics.minScrollExtent) {
      _showHeader(true);
    } else if (delta != null && delta != 0) {
      _showHeader(delta < 0);
    } else if (notification is UserScrollNotification && notification.direction != ScrollDirection.idle) {
      _showHeader(notification.direction == ScrollDirection.forward);
    }

    return false;
  }

  double _headerHeight(BuildContext context) {
    final title = widget.contextTitle;
    if (title == null) {
      return (MediaQuery.textScalerOf(context).scale(20) * 1.3 + 16).clamp(kToolbarHeight, double.infinity);
    }
    final painter = TextPainter(
      text: TextSpan(text: title, style: Theme.of(context).textTheme.titleLarge),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 2,
    )..layout(maxWidth: (MediaQuery.sizeOf(context).width - 144).clamp(1, double.infinity));
    final height = (painter.height + 16).clamp(kToolbarHeight, double.infinity);
    painter.dispose();

    return height;
  }

  void _showHeader(bool visible) {
    if (_headerVisible != visible) {
      setState(() => _headerVisible = visible);
    }
  }

  Future<void> _account() async {
    if (widget.onSignIn != null) {
      widget.onSignIn?.call();

      return;
    }
    if (_accountOpen) {
      return;
    }
    setState(() {
      _accountOpen = true;
      _headerVisible = true;
    });
    await showAppActionSheet<void>(
      context: context,
      builder: (sheetContext) => AppActionSheet(
        title: 'Аккаунт',
        mobileHeightFactor: 0.65,
        expandChild: true,
        child: ListView(
          children: [
            if (widget.accountName case final name?) ...[
              AccountIdentity(name: name, imageUrl: widget.accountImageUrl),
              const SizedBox(height: AppSpacing.lg),
            ],
            if (widget.onSignOut != null)
              ListTile(
                leading: const AppIcon(AppIconType.logOut),
                title: const Text('Выйти из аккаунта'),
                onTap: () => _closeAccount(sheetContext, widget.onSignOut),
              ),
            if (widget.onOpenLogs != null)
              ListTile(
                leading: const AppIcon(AppIconType.list),
                title: const Text('Открыть логи'),
                onTap: () => _closeAccount(sheetContext, widget.onOpenLogs),
              ),
          ],
        ),
      ),
    );
    if (mounted) {
      setState(() => _accountOpen = false);
    }
  }

  void _closeAccount(BuildContext sheetContext, VoidCallback? action) {
    Navigator.of(sheetContext).pop();
    action?.call();
  }

  void _handleBack(bool didPop, Object? _) {
    if (!didPop && _selected != 0) {
      _selectDestination(HomeDestination.home);
    } else if (!didPop) {
      widget.onRootBack?.call();
    }
  }

  @override
  void didUpdateWidget(covariant MobileHomeShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.destination != widget.destination) {
      _selected = widget.destination.index;
      _visited.add(_selected);
      _headerVisible = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final label = homeDestinationLabel(HomeDestination.values[_selected]);
    final headerVisible =
        _headerVisible ||
        AppMotion.reducedOf(context) ||
        MediaQuery.viewInsetsOf(context).bottom > 0 ||
        _accountOpen ||
        ModalRoute.of(context)?.isCurrent != true;
    final headerHeight = _headerHeight(context);
    final content = widget.content;

    return PopScope(
      canPop: !widget.root && widget.content != null || _selected == 0 && widget.onRootBack == null,
      onPopInvokedWithResult: _handleBack,
      child: Scaffold(
        extendBody: true,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(end: headerVisible ? 1 : 0),
                duration: AppMotion.durationOf(context, AppMotion.fast),
                curve: AppMotion.enterCurve,
                builder: (context, value, child) => ClipRect(
                  child: Align(alignment: Alignment.topCenter, heightFactor: value, child: child),
                ),
                child: ExcludeFocus(
                  excluding: !headerVisible,
                  child: ExcludeSemantics(
                    excluding: !headerVisible,
                    child: IgnorePointer(
                      ignoring: !headerVisible,
                      child: SizedBox(
                        height: headerHeight,
                        child: AppBar(
                          key: const ValueKey('mobile-header'),
                          primary: false,
                          toolbarHeight: headerHeight,
                          leading: widget.onBack == null
                              ? const Padding(padding: EdgeInsets.all(12), child: AnistarLogo(size: 32))
                              : IconButton(
                                  tooltip: 'Назад',
                                  onPressed: widget.onBack,
                                  icon: const AppIcon(AppIconType.arrowLeft),
                                ),
                          title: Text(widget.contextTitle ?? label, maxLines: 2, overflow: TextOverflow.ellipsis),
                          automaticallyImplyLeading: false,
                          actions: [
                            IconButton(
                              key: const ValueKey('mobile-account'),
                              tooltip: switch ((widget.onSignIn, widget.accountName)) {
                                (_?, _) => 'Войти',
                                (_, null) => 'Аккаунт',
                                (_, final account) => 'Аккаунт: $account',
                              },
                              onPressed: () => unawaited(_account()),
                              icon: AppIcon(widget.onSignIn != null ? AppIconType.logIn : AppIconType.user),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: content != null
                    ? NotificationListener<ScrollNotification>(onNotification: _onScroll, child: content)
                    : IndexedStack(
                        index: _selected,
                        children: List.generate(
                          HomeDestination.values.length,
                          (index) => NotificationListener<ScrollNotification>(
                            onNotification: (notification) => index == _selected && _onScroll(notification),
                            child: HeroMode(
                              enabled: index == _selected,
                              child: TickerMode(
                                enabled: index == _selected,
                                child: !_visited.contains(index)
                                    ? const SizedBox.shrink()
                                    : switch (index) {
                                        3 => SearchScreen(onAnimeTap: widget.onAnimeTap, active: _selected == 3),
                                        2 => GenresScreen(
                                          embedded: true,
                                          onSelected: widget.onGenreSelected ?? (_) => widget.onOpenGenres?.call(),
                                        ),
                                        _ => CatalogScreen(
                                          key: ValueKey('mobile-tab-$index'),
                                          embedded: true,
                                          favoritesOnly: index == 1,
                                          onAnimeTap: widget.onAnimeTap,
                                          onTabSelected: (favorite) => _selectDestination(
                                            favorite ? HomeDestination.favorites : HomeDestination.home,
                                          ),
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
              decoration: BoxDecoration(
                color: AppPalette.backgroundElevated.withValues(alpha: 0.92),
                border: const Border(top: BorderSide(color: AppPalette.outline)),
              ),
              child: NavigationBar(
                key: const ValueKey('mobile-navigation'),
                backgroundColor: Colors.transparent,
                surfaceTintColor: Colors.transparent,
                elevation: 0,
                height: MediaQuery.textScalerOf(context).scale(12) * 2 + 56,
                selectedIndex: _destinations
                    .indexOf(HomeDestination.values[_selected])
                    .clamp(0, _destinations.length - 1),
                onDestinationSelected: _select,
                destinations: [
                  for (final destination in _destinations)
                    NavigationDestination(
                      icon: AppIcon(switch (destination) {
                        HomeDestination.home => AppIconType.home,
                        HomeDestination.search => AppIconType.search,
                        HomeDestination.favorites => AppIconType.heart,
                        HomeDestination.genres => AppIconType.layoutGrid,
                      }),
                      label: homeDestinationLabel(destination),
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
