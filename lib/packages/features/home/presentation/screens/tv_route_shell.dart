import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';

import '../../../catalog/presentation/widgets/anime_card.dart';
import '../../../catalog/presentation/widgets/catalog_navigation_rail.dart';
import '../home_destination.dart';

/// The same menu/focus contract for root sections and nested routes.
class TvRouteShell extends StatefulWidget {
  const TvRouteShell({
    required this.builder,
    required this.destination,
    required this.onDestinationSelected,
    this.onSignOut,
    this.onSignIn,
    this.accountName,
    this.accountImageUrl,
    this.onOpenLogs,
    this.onRootBack,
    this.consumeBack,
    this.onActivateContent,
    this.root = false,
    this.fullScreen = false,
    this.restoreFocusOnDestinationChange = true,
    this.onExpansionChanged,
    this.controller,
    super.key,
  });

  final Widget Function(VoidCallback onOpenNavigation) builder;
  final HomeDestination destination;
  final ValueChanged<HomeDestination> onDestinationSelected;
  final VoidCallback? onSignOut;
  final VoidCallback? onSignIn;
  final String? accountName;
  final String? accountImageUrl;
  final VoidCallback? onOpenLogs;
  final VoidCallback? onRootBack;
  final bool Function()? consumeBack;
  final VoidCallback? onActivateContent;
  final bool root;
  final bool fullScreen;
  final bool restoreFocusOnDestinationChange;
  final ValueChanged<bool>? onExpansionChanged;
  final TvRouteShellController? controller;

  @override
  State<TvRouteShell> createState() => _TvRouteShellState();
}

class _TvRouteShellState extends State<TvRouteShell> {
  final _contentFocus = FocusScopeNode();
  final _menuFocus = {for (final destination in HomeDestination.values) destination: FocusNode()};
  final _accountFocus = FocusNode();
  final _logsFocus = FocusNode();
  FocusNode? _lastContentFocus;
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    widget.controller?.closeNavigation = _focusContent;
  }

  List<HomeDestination> get _destinations => homeDestinations(account: widget.onSignIn == null);

  void _openNavigation() {
    if (_contentFocus.hasFocus) {
      _lastContentFocus = FocusManager.instance.primaryFocus;
    }
    (_menuFocus[widget.destination] ?? _menuFocus[HomeDestination.home])?.requestFocus();
  }

  void _focusContent({bool first = false}) {
    // A modal route owns focus until it pops; deferred shell callbacks must not reclaim it.
    if (ModalRoute.of(context)?.isCurrent == false) {
      return;
    }
    if (first && widget.onActivateContent != null) {
      _contentFocus.requestFocus();
      widget.onActivateContent?.call();

      return;
    }
    final previous = first ? null : _lastContentFocus;
    if (previous?.context != null && previous?.canRequestFocus == true) {
      previous?.requestFocus();
    } else {
      (_contentFocus.traversalDescendants.where((node) => node.canRequestFocus && node.context != null).firstOrNull ??
              _contentFocus)
          .requestFocus();
    }
  }

  void _activate(HomeDestination destination) {
    if (widget.root && destination == widget.destination) {
      _focusContent();

      return;
    }
    _lastContentFocus = null;
    widget.onDestinationSelected(destination);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusContent(first: true);
      }
    });
  }

  // Leave both edges of Android's hardware BACK to system route dispatch.
  // Handling the down here can change focus before Android redispatches the up.
  bool _isKeyboardBack(LogicalKeyboardKey key) =>
      key == LogicalKeyboardKey.escape ||
      (key == LogicalKeyboardKey.goBack && (kIsWeb || defaultTargetPlatform != TargetPlatform.android));

  KeyEventResult _handleMenuKey(FocusNode node, KeyEvent event) {
    final key = event.logicalKey;
    if (_isKeyboardBack(key)) {
      if (event is KeyDownEvent) {
        _onPopInvoked(false, null);
      }

      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      if (event is KeyDownEvent || event is KeyRepeatEvent) {
        _focusContent();
      }

      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp || key == LogicalKeyboardKey.arrowDown) {
      if (event is KeyDownEvent || event is KeyRepeatEvent) {
        final nodes = [
          for (final destination in _destinations) _menuFocus[destination]!,
          if (widget.onSignIn != null || widget.onSignOut != null) _accountFocus,
          if (widget.onOpenLogs != null) _logsFocus,
        ];
        final index = nodes.indexOf(FocusManager.instance.primaryFocus ?? node);
        nodes[(index + (key == LogicalKeyboardKey.arrowDown ? 1 : -1)).clamp(0, nodes.length - 1)].requestFocus();
      }

      return KeyEventResult.handled;
    }

    return key == LogicalKeyboardKey.arrowLeft ? KeyEventResult.handled : KeyEventResult.ignored;
  }

  IconData _icon(HomeDestination destination) => switch (destination) {
    HomeDestination.home => Icons.home_outlined,
    HomeDestination.search => Icons.search,
    HomeDestination.favorites => Icons.favorite_border_rounded,
    HomeDestination.genres => Icons.category_outlined,
  };

  String _key(HomeDestination destination) => switch (destination) {
    HomeDestination.home => 'catalog-tab-false',
    HomeDestination.search => 'catalog-search',
    HomeDestination.favorites => 'catalog-tab-true',
    HomeDestination.genres => 'catalog-genres',
  };

  List<CatalogNavigationItem> _items() => [
    for (final destination in _destinations)
      (
        key: ValueKey(_key(destination)),
        icon: _icon(destination),
        label: homeDestinationLabel(destination),
        focusNode: _menuFocus[destination]!,
        onPressed: () => _activate(destination),
        selected: destination == widget.destination,
        autofocus: false,
      ),
    if (widget.onSignIn != null || widget.onSignOut != null)
      (
        key: ValueKey(widget.onSignIn != null ? 'catalog-sign-in' : 'catalog-account'),
        icon: widget.onSignIn != null ? Icons.login : Icons.logout,
        label: widget.onSignIn != null ? 'Войти' : 'Выйти из аккаунта',
        focusNode: _accountFocus,
        onPressed: () => (widget.onSignIn ?? widget.onSignOut)?.call(),
        selected: false,
        autofocus: false,
      ),
    if (widget.onOpenLogs case final action?)
      (
        key: const ValueKey('catalog-logs'),
        icon: Icons.article_outlined,
        label: 'Открыть логи',
        focusNode: _logsFocus,
        onPressed: action,
        selected: false,
        autofocus: false,
      ),
  ];

  void _onPopInvoked(bool didPop, Object? result) {
    if (didPop || widget.consumeBack?.call() == true) {
      return;
    }
    if (widget.root) {
      if (!_expanded) {
        _openNavigation();
      } else if (widget.destination != HomeDestination.home) {
        _activate(HomeDestination.home);
      } else {
        widget.onRootBack?.call();
      }
    } else if (_expanded) {
      _focusContent();
    }
  }

  KeyEventResult _handleContentKey(FocusNode node, KeyEvent event) {
    if (widget.root && _isKeyboardBack(event.logicalKey)) {
      if (event is KeyDownEvent) {
        _onPopInvoked(false, null);
      }

      return KeyEventResult.handled;
    }
    if (event.logicalKey != LogicalKeyboardKey.arrowLeft) {
      return KeyEventResult.ignored;
    }
    final focusContext = FocusManager.instance.primaryFocus?.context;
    final fromAnimeCard = focusContext?.findAncestorWidgetOfExactType<AnimeCard>() != null;
    if (fromAnimeCard) {
      return KeyEventResult.ignored;
    }
    final input = focusContext?.findAncestorWidgetOfExactType<EditableText>();
    if (input != null && !input.readOnly) {
      return KeyEventResult.ignored;
    }
    if (event is KeyDownEvent || event is KeyRepeatEvent) {
      _openNavigation();
    }

    return KeyEventResult.handled;
  }

  void _menuFocusChanged(bool focused) {
    if (_expanded != focused) {
      setState(() => _expanded = focused);
      widget.onExpansionChanged?.call(focused);
    }
  }

  @override
  void didUpdateWidget(covariant TvRouteShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.restoreFocusOnDestinationChange && oldWidget.destination != widget.destination) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focusContent(first: true);
      });
    }
  }

  @override
  void dispose() {
    _contentFocus.dispose();
    for (final node in _menuFocus.values) {
      node.dispose();
    }
    _accountFocus.dispose();
    _logsFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: widget.fullScreen || !widget.root && !_expanded,
    onPopInvokedWithResult: _onPopInvoked,
    child: TvBackdrop(
      child: Material(
        type: MaterialType.transparency,
        child: Stack(
          children: [
            Positioned.fill(
              left: widget.fullScreen ? 0 : CatalogNavigationRail.collapsedWidthOf(context),
              child: FocusScope(
                node: _contentFocus,
                onKeyEvent: _handleContentKey,
                child: widget.builder(_openNavigation),
              ),
            ),
            if (!widget.fullScreen)
              Positioned.fill(
                left: CatalogNavigationRail.collapsedWidthOf(context),
                child: IgnorePointer(
                  ignoring: !_expanded,
                  child: AnimatedOpacity(
                    opacity: _expanded ? 1 : 0,
                    duration: AppMotion.durationOf(context, _expanded ? AppMotion.panelEnter : AppMotion.panelExit),
                    child: GestureDetector(
                      onTap: _focusContent,
                      child: const ColoredBox(color: AppPalette.scrim),
                    ),
                  ),
                ),
              ),
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: Offstage(
                offstage: widget.fullScreen,
                child: Focus(
                  onFocusChange: _menuFocusChanged,
                  onKeyEvent: _handleMenuKey,
                  child: CatalogNavigationRail(
                    expanded: _expanded,
                    items: _items(),
                    accountName: widget.accountName,
                    accountImageUrl: widget.accountImageUrl,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class TvRouteShellController {
  VoidCallback? openNavigation;
  VoidCallback? closeNavigation;
  VoidCallback? focusFirst;
  bool Function()? consumeBack;
  Object? owner;
  final expanded = ValueNotifier(false);
  final playerVisible = ValueNotifier(false);

  void clear(Object owner) {
    if (!identical(this.owner, owner)) return;
    this.owner = null;
    focusFirst = null;
    consumeBack = null;
  }
}

class TvRouteShellScope extends InheritedWidget {
  const TvRouteShellScope({required this.controller, required super.child, super.key});

  final TvRouteShellController controller;

  static TvRouteShellController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<TvRouteShellScope>()?.controller;

  @override
  bool updateShouldNotify(TvRouteShellScope oldWidget) => controller != oldWidget.controller;
}
