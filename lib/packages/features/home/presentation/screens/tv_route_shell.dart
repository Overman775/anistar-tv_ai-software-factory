import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';

import '../../../catalog/presentation/widgets/catalog_navigation_rail.dart';
import '../home_destination.dart';

/// Persistent TV navigation for a route that does not own a catalog.
class TvRouteShell extends StatefulWidget {
  const TvRouteShell({
    required this.builder,
    required this.destination,
    required this.onDestinationSelected,
    required this.onSignOut,
    this.accountName,
    this.onOpenLogs,
    super.key,
  });

  final Widget Function(VoidCallback onOpenNavigation) builder;
  final HomeDestination destination;
  final ValueChanged<HomeDestination> onDestinationSelected;
  final VoidCallback onSignOut;
  final String? accountName;
  final VoidCallback? onOpenLogs;

  @override
  State<TvRouteShell> createState() => _TvRouteShellState();
}

class _TvRouteShellState extends State<TvRouteShell> {
  final _contentFocus = FocusScopeNode();
  final _menuFocus = List.generate(5, (_) => FocusNode());
  FocusNode? _lastContentFocus;
  bool _expanded = false;

  void _openNavigation() {
    _lastContentFocus = FocusManager.instance.primaryFocus;
    _menuFocus[widget.destination.index].requestFocus();
  }

  void _focusContent() {
    final previous = _lastContentFocus;
    if (previous?.context != null && previous?.canRequestFocus == true) {
      previous?.requestFocus();
    } else {
      (_contentFocus.traversalDescendants.where((node) => node.canRequestFocus).firstOrNull ?? _contentFocus)
          .requestFocus();
    }
  }

  KeyEventResult _handleMenuKey(FocusNode node, KeyEvent event) {
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowRight || key == LogicalKeyboardKey.escape) {
      if (event is KeyDownEvent || event is KeyRepeatEvent) {
        _focusContent();
      }

      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp || key == LogicalKeyboardKey.arrowDown) {
      if (event is KeyDownEvent || event is KeyRepeatEvent) {
        final index = _menuFocus.indexOf(FocusManager.instance.primaryFocus ?? node);
        final last = widget.onOpenLogs == null ? 3 : 4;
        _menuFocus[(index + (key == LogicalKeyboardKey.arrowDown ? 1 : -1)).clamp(0, last)].requestFocus();
      }

      return KeyEventResult.handled;
    }

    return key == LogicalKeyboardKey.arrowLeft ? KeyEventResult.handled : KeyEventResult.ignored;
  }

  List<CatalogNavigationItem> _items() {
    const labels = ['Главная', 'Избранное', 'Жанры', 'Выйти из аккаунта', 'Открыть логи'];
    const icons = [
      Icons.home_outlined,
      Icons.favorite_border_rounded,
      Icons.category_outlined,
      Icons.account_circle_outlined,
      Icons.article_outlined,
    ];
    const keys = ['catalog-tab-false', 'catalog-tab-true', 'catalog-genres', 'catalog-account', 'catalog-logs'];

    return List.generate(
      widget.onOpenLogs == null ? 4 : 5,
      (index) => (
        key: ValueKey(keys[index]),
        icon: icons[index],
        label: labels[index],
        focusNode: _menuFocus[index],
        onPressed: () => _selectItem(index),
        selected: index == widget.destination.index,
        autofocus: false,
      ),
    );
  }

  void _selectItem(int index) {
    if (index < 3) {
      widget.onDestinationSelected(HomeDestination.values[index]);
    } else if (index == 3) {
      widget.onSignOut();
    } else {
      widget.onOpenLogs?.call();
    }
  }

  void _onPopInvoked(bool didPop, Object? result) {
    if (!didPop && _expanded) {
      _focusContent();
    }
  }

  KeyEventResult _handleContentKey(FocusNode node, KeyEvent event) {
    if (event.logicalKey != LogicalKeyboardKey.arrowLeft) {
      return KeyEventResult.ignored;
    }
    if (event is KeyDownEvent || event is KeyRepeatEvent) {
      _openNavigation();
    }

    return KeyEventResult.handled;
  }

  void _onMenuFocusChanged(bool focused) {
    if (_expanded != focused) {
      setState(() => _expanded = focused);
    }
  }

  @override
  void dispose() {
    _contentFocus.dispose();
    for (final node in _menuFocus) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_expanded,
    onPopInvokedWithResult: _onPopInvoked,
    child: Stack(
      children: [
        Positioned.fill(
          left: CatalogNavigationRail.collapsedWidth,
          child: FocusScope(node: _contentFocus, onKeyEvent: _handleContentKey, child: widget.builder(_openNavigation)),
        ),
        Positioned.fill(
          left: CatalogNavigationRail.collapsedWidth,
          child: IgnorePointer(
            ignoring: !_expanded,
            child: AnimatedOpacity(
              opacity: _expanded ? 1 : 0,
              duration: AppMotion.durationOf(context, _expanded ? AppMotion.panelEnter : AppMotion.panelExit),
              child: GestureDetector(
                onTap: _focusContent,
                child: ColoredBox(color: Colors.black.withValues(alpha: 0.45)),
              ),
            ),
          ),
        ),
        Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          child: Focus(
            onFocusChange: _onMenuFocusChanged,
            onKeyEvent: _handleMenuKey,
            child: CatalogNavigationRail(expanded: _expanded, items: _items(), accountName: widget.accountName),
          ),
        ),
      ],
    ),
  );
}
