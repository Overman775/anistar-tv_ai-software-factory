import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';

import '../../../catalog/domain/models/anime_summary.dart';
import '../../../catalog/domain/models/catalog_filter.dart';
import '../../../catalog/presentation/screens/catalog_screen.dart';
import '../../../catalog/presentation/screens/genres_screen.dart';
import '../../../favorites/favorites_providers.dart';
import '../../../search/presentation/search_screen.dart';
import '../home_destination.dart';
import '../mobile/mobile_home_shell.dart';
import 'tv_route_shell.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({
    required this.onAnimeTap,
    this.onOpenLogs,
    this.onOpenGenres,
    this.onGenreSelected,
    this.onSignOut,
    this.onSignIn,
    this.accountName,
    this.accountImageUrl,
    this.onRootBack,
    this.destination = HomeDestination.home,
    this.onDestinationSelected,
    super.key,
  });

  final ValueChanged<CatalogFilter>? onGenreSelected;
  final String? accountName;
  final String? accountImageUrl;
  final ValueChanged<AnimeSummary> onAnimeTap;
  final VoidCallback? onOpenLogs;
  final VoidCallback? onOpenGenres;
  final VoidCallback? onSignOut;
  final VoidCallback? onSignIn;
  final VoidCallback? onRootBack;
  final HomeDestination destination;
  final ValueChanged<HomeDestination>? onDestinationSelected;

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  late HomeDestination _destination;
  final _visited = <HomeDestination>{};
  final _search = GlobalKey<SearchScreenState>();
  final _home = GlobalKey<CatalogScreenState>();
  final _favorites = GlobalKey<CatalogScreenState>();
  final _genres = GlobalKey<GenresScreenState>();

  @override
  void initState() {
    super.initState();
    _destination = widget.destination == HomeDestination.favorites && widget.onSignIn != null
        ? HomeDestination.home
        : widget.destination;
    _visited.add(_destination);
    if (_destination != widget.destination) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          widget.onSignIn?.call();
        }
      });
    }
  }

  Widget _sections(VoidCallback? onNavigation) => IndexedStack(
    index: _destination.index,
    children: [
      for (final destination in HomeDestination.values)
        HeroMode(
          enabled: destination == _destination,
          child: TickerMode(
            enabled: destination == _destination,
            child: ExcludeFocus(
              excluding: destination != _destination,
              child: !_visited.contains(destination)
                  ? const SizedBox.shrink()
                  : switch (destination) {
                      HomeDestination.home || HomeDestination.favorites => CatalogScreen(
                        key: destination == HomeDestination.home ? _home : _favorites,
                        embedded: true,
                        favoritesOnly: destination == HomeDestination.favorites,
                        onTabSelected: (favorite) =>
                            _select(favorite ? HomeDestination.favorites : HomeDestination.home),
                        onOpenNavigation: onNavigation,
                        onAnimeTap: widget.onAnimeTap,
                      ),
                      HomeDestination.genres => GenresScreen(
                        key: _genres,
                        embedded: true,
                        autofocus: destination == _destination,
                        onOpenNavigation: onNavigation,
                        onSelected: widget.onGenreSelected ?? (_) => widget.onOpenGenres?.call(),
                      ),
                      HomeDestination.search => SearchScreen(
                        key: _search,
                        active: destination == _destination,
                        onOpenNavigation: onNavigation,
                        onAnimeTap: widget.onAnimeTap,
                      ),
                    },
            ),
          ),
        ),
    ],
  );

  void _focusFirst() {
    switch (_destination) {
      case HomeDestination.home:
        _home.currentState?.focusFirst();
      case HomeDestination.favorites:
        _favorites.currentState?.focusFirst();
      case HomeDestination.genres:
        _genres.currentState?.focusFirst();
      case HomeDestination.search:
        _search.currentState?.focusFirst();
    }
  }

  void _refreshSection(HomeDestination destination, {bool refreshCatalog = true}) {
    ref.read(favoritesControllerProvider.notifier).invalidate();
    if (!refreshCatalog) {
      return;
    }
    switch (destination) {
      case HomeDestination.home:
        _home.currentState?.refresh();
      case HomeDestination.favorites:
        _favorites.currentState?.refresh();
      case HomeDestination.genres || HomeDestination.search:
        break;
    }
  }

  void _select(HomeDestination destination) {
    if (destination == HomeDestination.favorites && widget.onSignIn != null) {
      widget.onSignIn?.call();

      return;
    }
    final callback = widget.onDestinationSelected;
    if (callback != null) {
      callback(destination);

      return;
    }
    final changed = _destination != destination;
    setState(() {
      _destination = destination;
      _visited.add(destination);
    });
    if (changed) {
      _refreshSection(destination);
    }
  }

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.destination == HomeDestination.favorites && widget.onSignIn != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          widget.onSignIn?.call();
        }
      });
    } else {
      final changed = _destination != widget.destination;
      final wasVisited = _visited.contains(widget.destination);
      _destination = widget.destination;
      _visited.add(_destination);
      if (changed) {
        final destination = _destination;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _destination == destination) {
            _refreshSection(destination, refreshCatalog: wasVisited);
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => !AppLayoutScope.isTvOf(context)
      ? MobileHomeShell(
          accountName: widget.accountName,
          accountImageUrl: widget.accountImageUrl,
          destination: _destination,
          onDestinationSelected: _select,
          onAnimeTap: widget.onAnimeTap,
          onOpenLogs: widget.onOpenLogs,
          onOpenGenres: widget.onOpenGenres,
          onGenreSelected: widget.onGenreSelected,
          onSignOut: widget.onSignOut,
          onSignIn: widget.onSignIn,
          onRootBack: widget.onRootBack,
          root: true,
          content: Builder(builder: (_) => _sections(null)),
        )
      : Scaffold(
          backgroundColor: AppPalette.background,
          body: SafeArea(
            child: TvRouteShell(
              destination: _destination,
              accountName: widget.accountName,
              accountImageUrl: widget.accountImageUrl,
              onDestinationSelected: _select,
              onSignOut: widget.onSignOut,
              onSignIn: widget.onSignIn,
              onOpenLogs: widget.onOpenLogs,
              onRootBack: widget.onRootBack,
              root: true,
              onActivateContent: _focusFirst,
              consumeBack: () =>
                  _destination == HomeDestination.search && (_search.currentState?.finishEditing() ?? false),
              builder: _sections,
            ),
          ),
        );
}
