import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../catalog/domain/models/anime_summary.dart';
import '../../../catalog/presentation/screens/catalog_screen.dart';
import '../../../favorites/favorites_providers.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({required this.onAnimeTap, this.onOpenLogs, this.onSignOut, super.key});

  final ValueChanged<AnimeSummary> onAnimeTap;
  final VoidCallback? onOpenLogs;
  final VoidCallback? onSignOut;

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _favoritesOnly = false;

  void _selectTab(bool favorite) {
    if (favorite != _favoritesOnly) {
      ref.read(favoritesControllerProvider.notifier).invalidate();
      setState(() => _favoritesOnly = favorite);
    }
  }

  @override
  Widget build(BuildContext context) => CatalogScreen(
    key: ValueKey(_favoritesOnly),
    favoritesOnly: _favoritesOnly,
    onTabSelected: _selectTab,
    onAnimeTap: widget.onAnimeTap,
    onOpenLogs: widget.onOpenLogs,
    onSignOut: widget.onSignOut,
  );
}
