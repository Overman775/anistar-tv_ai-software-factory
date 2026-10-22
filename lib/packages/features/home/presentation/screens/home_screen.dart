import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';

import '../../../catalog/domain/models/anime_summary.dart';
import '../../../catalog/domain/models/catalog_filter.dart';
import '../../../catalog/presentation/screens/catalog_screen.dart';
import '../../../catalog/presentation/screens/genres_screen.dart';
import '../../../favorites/favorites_providers.dart';
import '../home_destination.dart';
import '../mobile/mobile_home_shell.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({
    required this.onAnimeTap,
    this.onOpenLogs,
    this.onOpenGenres,
    this.onGenreSelected,
    this.onSignOut,
    this.accountName,
    this.onRootBack,
    this.destination = HomeDestination.home,
    this.onDestinationSelected,
    super.key,
  });

  final ValueChanged<CatalogFilter>? onGenreSelected;
  final String? accountName;
  final ValueChanged<AnimeSummary> onAnimeTap;
  final VoidCallback? onOpenLogs;
  final VoidCallback? onOpenGenres;
  final VoidCallback? onSignOut;
  final VoidCallback? onRootBack;
  final HomeDestination destination;
  final ValueChanged<HomeDestination>? onDestinationSelected;

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  late bool _favoritesOnly;
  late bool _genresActive;
  late bool _genresVisited;
  bool _autofocusTab = false;
  int _destinationGeneration = 0;

  @override
  void initState() {
    super.initState();
    _favoritesOnly = widget.destination == HomeDestination.favorites;
    _genresActive = widget.destination == HomeDestination.genres;
    _genresVisited = _genresActive;
  }

  void _openGenres() {
    final onSelected = widget.onDestinationSelected;
    if (onSelected != null) {
      onSelected(HomeDestination.genres);

      return;
    }
    setState(() {
      _genresActive = true;
      _genresVisited = true;
    });
  }

  void _handleRootBack() {
    if (_genresActive) {
      _selectTab(false);
    } else {
      widget.onRootBack?.call();
    }
  }

  Widget _genresSection(VoidCallback onOpenNavigation) => GenresScreen(
    embedded: true,
    autofocus: false,
    onOpenNavigation: onOpenNavigation,
    onSelected: widget.onGenreSelected ?? (_) => widget.onOpenGenres?.call(),
  );

  void _selectTab(bool favorite) {
    final onSelected = widget.onDestinationSelected;
    if (onSelected != null) {
      onSelected(favorite ? HomeDestination.favorites : HomeDestination.home);

      return;
    }
    if (favorite != _favoritesOnly || _genresActive) {
      ref.read(favoritesControllerProvider.notifier).invalidate();
      setState(() {
        _favoritesOnly = favorite;
        _genresActive = false;
        _autofocusTab = true;
      });
    }
  }

  void _invalidateAfterDestinationChange() {
    final generation = _destinationGeneration;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && generation == _destinationGeneration) {
        ref.read(favoritesControllerProvider.notifier).invalidate();
      }
    });
  }

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.destination != widget.destination) {
      _destinationGeneration++;
      final genres = widget.destination == HomeDestination.genres;
      if (!genres) {
        final favorite = widget.destination == HomeDestination.favorites;
        if (_favoritesOnly != favorite) {
          _invalidateAfterDestinationChange();
        }
        _favoritesOnly = favorite;
      }
      _genresActive = genres;
      _genresVisited = _genresVisited || genres;
      _autofocusTab = !genres;
    }
  }

  @override
  Widget build(BuildContext context) => !AppLayoutScope.isTvOf(context)
      ? MobileHomeShell(
          accountName: widget.accountName,
          destination: widget.destination,
          onDestinationSelected: widget.onDestinationSelected,
          onAnimeTap: widget.onAnimeTap,
          onOpenLogs: widget.onOpenLogs,
          onOpenGenres: widget.onOpenGenres,
          onGenreSelected: widget.onGenreSelected,
          onSignOut: widget.onSignOut,
          onRootBack: widget.onRootBack,
        )
      : CatalogScreen(
          accountName: widget.accountName,
          favoritesOnly: _favoritesOnly,
          autofocusTab: _autofocusTab,
          onTabSelected: _selectTab,
          onAnimeTap: widget.onAnimeTap,
          onOpenLogs: widget.onOpenLogs,
          onOpenGenres: _openGenres,
          onSignOut: widget.onSignOut,
          onRootBack: _genresActive || widget.onRootBack != null ? _handleRootBack : null,
          genresActive: _genresActive,
          sectionBuilder: _genresVisited ? _genresSection : null,
        );
}
