import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';

import '../../../catalog/domain/models/anime_summary.dart';
import '../../../catalog/presentation/screens/catalog_screen.dart';
import '../../../favorites/favorites_providers.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({required this.onAnimeTap, this.onOpenLogs, this.onSignOut, this.accountName, super.key});

  final String? accountName;
  final ValueChanged<AnimeSummary> onAnimeTap;
  final VoidCallback? onOpenLogs;
  final VoidCallback? onSignOut;

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _favoritesOnly = false;
  bool _autofocusTab = false;

  void _selectTab(bool favorite) {
    if (favorite != _favoritesOnly) {
      ref.read(favoritesControllerProvider.notifier).invalidate();
      setState(() {
        _favoritesOnly = favorite;
        _autofocusTab = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    key: ValueKey(_favoritesOnly),
    tween: Tween(begin: 0, end: 1),
    duration: AppMotion.durationOf(context, AppMotion.fast),
    curve: AppMotion.enterCurve,
    builder: (context, value, child) => Opacity(opacity: value, child: child),
    child: CatalogScreen(
      accountName: widget.accountName,
      favoritesOnly: _favoritesOnly,
      autofocusTab: _autofocusTab,
      onTabSelected: _selectTab,
      onAnimeTap: widget.onAnimeTap,
      onOpenLogs: widget.onOpenLogs,
      onSignOut: widget.onSignOut,
    ),
  );
}
