import 'dart:async';
import 'dart:math' as math;

import 'package:core/data.dart';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';

import '../../catalog_providers.dart';
import '../../domain/models/catalog_filter.dart';

class GenresScreen extends ConsumerStatefulWidget {
  const GenresScreen({required this.onSelected, this.embedded = false, super.key});

  final ValueChanged<CatalogFilter> onSelected;
  final bool embedded;

  @override
  ConsumerState<GenresScreen> createState() => _GenresScreenState();
}

class _GenresScreenState extends ConsumerState<GenresScreen> {
  final _retry = FocusNode(debugLabel: 'Повторить загрузку жанров');
  bool _stateActionFocused = false;
  final _back = FocusNode(debugLabel: 'Назад из жанров');
  final Map<String, FocusNode> _nodes = {};
  int _columns = 1;
  List<CatalogFilter> _items = [];
  bool _focusedInitial = false;

  KeyEventResult _navigate(FocusNode node, KeyEvent event) {
    final current = FocusManager.instance.primaryFocus;
    final index = _items.indexWhere((item) => _nodes[item.path] == current);
    final key = event.logicalKey;
    FocusNode? target;
    if (current == _back && key == LogicalKeyboardKey.arrowDown && _items.isNotEmpty) {
      target = _nodes[_items.first.path];
    } else if (index >= 0) {
      var next = index;
      if (key == LogicalKeyboardKey.arrowUp) {
        if (index < _columns) {
          target = _back;
        } else {
          next -= _columns;
        }
      } else if (key == LogicalKeyboardKey.arrowDown) {
        next = (index + _columns).clamp(0, _items.length - 1);
      } else if (key == LogicalKeyboardKey.arrowLeft) {
        next = index % _columns == 0 ? index : index - 1;
      } else if (key == LogicalKeyboardKey.arrowRight) {
        next = index % _columns == _columns - 1 ? index : (index + 1).clamp(0, _items.length - 1);
      } else {
        return KeyEventResult.ignored;
      }
      target ??= _nodes[_items[next].path];
    }
    if (target == null) {
      return KeyEventResult.ignored;
    }
    if (event is KeyDownEvent || event is KeyRepeatEvent) {
      target.requestFocus();
    }

    return KeyEventResult.handled;
  }

  Widget _stateView(String title, String message) {
    _items = [];
    _focusedInitial = false;
    if (AppLayoutScope.isTvOf(context) && !_stateActionFocused) {
      _stateActionFocused = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && ModalRoute.of(context)?.isCurrent == true) {
          _retry.requestFocus();
        }
      });
    }

    return Padding(
      padding: EdgeInsets.only(
        bottom: widget.embedded && !AppLayoutScope.isTvOf(context) ? MediaQuery.paddingOf(context).bottom : 0,
      ),
      child: TvStateView(
        icon: Icons.category_outlined,
        title: title,
        message: message,
        actionLabel: 'Повторить',
        actionFocusNode: _retry,
        onAction: _reload,
      ),
    );
  }

  void _reload() {
    _stateActionFocused = false;
    ref.invalidate(genresProvider);
  }

  Future<void> _refreshMobile() async {
    ref.invalidate(genresProvider);
    try {
      await ref.read(genresProvider.future);
    } on Object {
      // Provider's error state keeps the recovery action visible.
    }
  }

  void _onTileFocus(BuildContext context, bool focused) {
    if (focused) {
      unawaited(
        Scrollable.ensureVisible(context, alignment: 0.5, duration: AppMotion.durationOf(context, AppMotion.fast)),
      );
    }
  }

  @override
  void dispose() {
    _back.dispose();
    _retry.dispose();
    for (final node in _nodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Focus(
    canRequestFocus: false,
    onKeyEvent: _navigate,
    child: TvBackdrop(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: widget.embedded
            ? null
            : AppBar(
                title: const Text('Аниме по жанрам'),
                leading: IconButton(
                  focusNode: _back,
                  autofocus: AppLayoutScope.isTvOf(context),
                  tooltip: 'Назад',
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.arrow_back),
                ),
              ),
        body: SafeArea(
          top: !widget.embedded,
          bottom: !widget.embedded,
          child: ref
              .watch(genresProvider)
              .when(
                skipLoadingOnRefresh: false,
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => _stateView(
                  'Жанры недоступны',
                  error is Failure ? error.message : 'Не удалось загрузить жанры. Повторите попытку.',
                ),
                data: (items) {
                  _items = items;
                  if (AppLayoutScope.isTvOf(context) && !_focusedInitial && items.isNotEmpty) {
                    _focusedInitial = true;
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted && ModalRoute.of(context)?.isCurrent == true) {
                        _nodes[items.first.path]?.requestFocus();
                      }
                    });
                  }
                  if (items.isEmpty) {
                    return _stateView('Жанры не найдены', 'Обновите список жанров.');
                  }
                  _stateActionFocused = false;
                  // Keep every tile mounted so D-pad traversal also reaches offscreen rows.

                  return LayoutBuilder(
                    builder: (context, constraints) {
                      if (!AppLayoutScope.isTvOf(context)) {
                        return RefreshIndicator(
                          onRefresh: _refreshMobile,
                          child: ListView.separated(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: EdgeInsets.fromLTRB(
                              AppLayoutScope.horizontalPaddingOf(context),
                              8,
                              AppLayoutScope.horizontalPaddingOf(context),
                              (widget.embedded ? MediaQuery.paddingOf(context).bottom : 0) + 8,
                            ),
                            itemCount: items.length,
                            separatorBuilder: (_, _) => const Divider(height: 1),
                            itemBuilder: (context, index) => ListTile(
                              contentPadding: const EdgeInsets.all(8),
                              title: Text(items[index].label),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => widget.onSelected(items[index]),
                            ),
                          ),
                        );
                      }
                      final textScale = MediaQuery.textScalerOf(context).scale(19) / 19;
                      _columns = switch (constraints.maxWidth / textScale) {
                        < 300 => 1,
                        < 600 => 2,
                        < 1100 => 3,
                        _ => 4,
                      };
                      final width = (constraints.maxWidth - 48 - (_columns - 1) * 16) / _columns;
                      final style = Theme.of(context).textTheme.titleMedium;
                      final lineHeight =
                          MediaQuery.textScalerOf(context).scale(style?.fontSize ?? 19) * (style?.height ?? 1.5);

                      return SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: Wrap(
                          spacing: 16,
                          runSpacing: 16,
                          children: [
                            for (final item in items)
                              SizedBox(
                                width: width,
                                height: math.max(72, lineHeight * 2 + 12),
                                child: Builder(
                                  builder: (tileContext) => TvFocusable(
                                    focusNode: _nodes.putIfAbsent(item.path, () => FocusNode(debugLabel: item.label)),
                                    semanticLabel: item.label,
                                    onPressed: () => widget.onSelected(item),
                                    onFocusChanged: (focused) => _onTileFocus(tileContext, focused),
                                    builder: (context, focused) => AnimatedContainer(
                                      duration: AppMotion.durationOf(context, AppMotion.fast),
                                      decoration: AppFocusStyle.decoration(
                                        focused: focused,
                                        restingColor: AppPalette.surfaceElevated,
                                      ),
                                      child: Center(
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 12),
                                          child: Text(
                                            item.label,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: style?.copyWith(color: AppPalette.textPrimary),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
        ),
      ),
    ),
  );
}
