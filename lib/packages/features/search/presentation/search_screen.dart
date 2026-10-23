import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';

import '../../auth/auth_providers.dart';
import '../../catalog/domain/models/anime_summary.dart';
import '../../catalog/presentation/widgets/anime_rating_badge.dart';
import '../../catalog/presentation/widgets/catalog_inspector.dart';
import '../../catalog/presentation/widgets/catalog_layout.dart';
import '../../catalog/presentation/widgets/catalog_skeleton.dart';
import '../../favorites/presentation/favorite_actions_sheet.dart';
import '../search_providers.dart';
import 'search_bloc.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({required this.onAnimeTap, this.onOpenNavigation, this.active = true, super.key});

  final ValueChanged<AnimeSummary> onAnimeTap;
  final VoidCallback? onOpenNavigation;
  final bool active;

  @override
  ConsumerState<SearchScreen> createState() => SearchScreenState();
}

class SearchScreenState extends ConsumerState<SearchScreen> {
  late final SearchBloc _bloc;
  final _query = TextEditingController();
  final _field = FocusNode(debugLabel: 'Поиск: название');
  final _clear = FocusNode(debugLabel: 'Очистить запрос');
  final _submit = FocusNode(debugLabel: 'Найти');
  final _retry = FocusNode(debugLabel: 'Повторить загрузку');
  int? _retryCardId;
  double? _retryScrollOffset;
  bool _restoringRetryCard = false;
  final _scroll = ScrollController();
  final Map<int, FocusNode> _cards = {};
  final Map<String, FocusNode> _history = {};
  bool _editing = false;
  String _draft = '';
  bool _keyboardVisible = false;
  int? _selectedId;
  int _columns = 1;

  @override
  void initState() {
    super.initState();
    _bloc = SearchBloc(ref.read(searchRepositoryProvider), ref.read(searchHistoryRepositoryProvider));
    _query.addListener(_inputChanged);
    _field.addListener(_fieldChanged);
    _scroll.addListener(_loadMore);
    if (widget.active) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _focusField());
    }
  }

  void _inputChanged() => setState(() => _draft = _query.text);
  void _fieldChanged() {
    setState(() => _editing = _field.hasFocus && _editing);
  }

  void focusFirst() => _focusField();

  void _focusField() {
    if (mounted && widget.active && AppLayoutScope.isTvOf(context) && ModalRoute.of(context)?.isCurrent == true) {
      _field.requestFocus();
    }
  }

  /// The owning root shell calls this before handling Android system Back.
  bool finishEditing() {
    if (!_editing) {
      return false;
    }
    setState(() => _editing = false);
    unawaited(SystemChannels.textInput.invokeMethod<void>('TextInput.hide'));
    _field.requestFocus();

    return true;
  }

  void _startEditing() {
    setState(() => _editing = true);
    _field.requestFocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _editing) {
        unawaited(SystemChannels.textInput.invokeMethod<void>('TextInput.show'));
      }
    });
  }

  void _search([String? query]) {
    if (query != null) {
      _query.text = query;
    }
    finishEditing();
    _field.requestFocus();
    _selectedId = null;
    if (_scroll.hasClients) {
      _scroll.jumpTo(0);
    }
    _bloc.add(SearchSubmitted(_query.text));
  }

  void _loadMore() {
    if (_scroll.hasClients && _scroll.position.extentAfter < 400) {
      _bloc.add(const SearchMoreRequested());
    }
  }

  void _focusBody() {
    final state = _bloc.state;
    final items = state.items;
    if (items.isNotEmpty) {
      _cards[items.first.id]?.requestFocus();
    } else if (state.status == SearchStatus.idle && state.history.isNotEmpty) {
      _history[state.history.first]?.requestFocus();
    }
  }

  KeyEventResult _formKey(FocusNode node, KeyEvent event) {
    if (!AppLayoutScope.isTvOf(context)) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (_editing) {
      if (key != LogicalKeyboardKey.escape && key != LogicalKeyboardKey.goBack) {
        return KeyEventResult.ignored;
      }
      if (event is KeyDownEvent) {
        finishEditing();
      }

      return KeyEventResult.handled;
    }
    if (_field.hasFocus &&
        (key == LogicalKeyboardKey.enter ||
            key == LogicalKeyboardKey.select ||
            key == LogicalKeyboardKey.numpadEnter)) {
      if (event is KeyDownEvent) {
        _startEditing();
      }

      return KeyEventResult.handled;
    }
    if (![
      LogicalKeyboardKey.arrowUp,
      LogicalKeyboardKey.arrowDown,
      LogicalKeyboardKey.arrowLeft,
      LogicalKeyboardKey.arrowRight,
    ].contains(key)) {
      return KeyEventResult.ignored;
    }
    if (event is KeyDownEvent || event is KeyRepeatEvent) {
      final nodes = [_field, if (_draft.isNotEmpty) _clear, _submit];
      final index = nodes.indexWhere((focus) => focus.hasFocus);
      if (key == LogicalKeyboardKey.arrowDown) {
        _focusBody();
      } else if (key == LogicalKeyboardKey.arrowUp) {
        _field.requestFocus();
      } else if (key == LogicalKeyboardKey.arrowLeft && index == 0) {
        widget.onOpenNavigation?.call();
      } else if (index >= 0) {
        nodes[(index + (key == LogicalKeyboardKey.arrowRight ? 1 : -1)).clamp(0, nodes.length - 1)].requestFocus();
      }
    }

    return KeyEventResult.handled;
  }

  KeyEventResult _cardKey(KeyEvent event, int index) {
    final key = event.logicalKey;
    if (![
      LogicalKeyboardKey.arrowUp,
      LogicalKeyboardKey.arrowDown,
      LogicalKeyboardKey.arrowLeft,
      LogicalKeyboardKey.arrowRight,
    ].contains(key)) {
      return KeyEventResult.ignored;
    }
    if (event is KeyDownEvent || event is KeyRepeatEvent) {
      var target = index;
      if (key == LogicalKeyboardKey.arrowUp) {
        if (index < _columns) {
          _field.requestFocus();

          return KeyEventResult.handled;
        }
        target -= _columns;
      } else if (key == LogicalKeyboardKey.arrowDown) {
        target += _columns;
      } else if (key == LogicalKeyboardKey.arrowLeft) {
        if (index % _columns == 0) {
          widget.onOpenNavigation?.call();

          return KeyEventResult.handled;
        }
        target--;
      } else if (index % _columns != _columns - 1) {
        target++;
      }
      final state = _bloc.state;
      final items = state.items;
      if (target >= 0 && target < items.length) {
        _cards[items[target].id]?.requestFocus();
      }
      if (target >= items.length) {
        if (state.message != null) {
          _retryCardId = items[index].id;
          _retryScrollOffset = _scroll.hasClients ? _scroll.offset : null;
          _retry.requestFocus();
          _reveal(_retry);
        } else {
          _bloc.add(const SearchMoreRequested());
        }
      }
    }

    return KeyEventResult.handled;
  }

  KeyEventResult _retryKey(FocusNode node, KeyEvent event) {
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowUp || key == LogicalKeyboardKey.arrowLeft) {
      if (event is KeyDownEvent || event is KeyRepeatEvent) {
        if (key == LogicalKeyboardKey.arrowUp) {
          _restoreRetryCard();
        } else {
          widget.onOpenNavigation?.call();
        }
      }

      return KeyEventResult.handled;
    }

    return key == LogicalKeyboardKey.arrowDown || key == LogicalKeyboardKey.arrowRight
        ? KeyEventResult.handled
        : KeyEventResult.ignored;
  }

  void _restoreRetryCard() {
    final node = _cards[_retryCardId ?? _bloc.state.items.lastOrNull?.id];
    if (node == null) {
      return;
    }
    _restoringRetryCard = true;
    node.requestFocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _restoringRetryCard = false;
      final offset = _retryScrollOffset;
      if (mounted && node.hasFocus && offset != null && _scroll.hasClients) {
        _scroll.jumpTo(offset.clamp(_scroll.position.minScrollExtent, _scroll.position.maxScrollExtent));
      }
    });
  }

  void _searchStateChanged(BuildContext context, SearchState state) {
    if (_retry.hasFocus && state.status == SearchStatus.ready && !state.loadingMore && state.message == null) {
      _restoreRetryCard();
    }
  }

  void _reveal(FocusNode node) {
    final target = node.context;
    if (target != null) {
      unawaited(
        Scrollable.ensureVisible(target, alignment: 0.5, duration: AppMotion.durationOf(context, AppMotion.fast)),
      );
    }
  }

  void _openAnime(AnimeSummary anime) {
    _selectedId = anime.id;
    widget.onAnimeTap(anime);
  }

  void _cardFocused(bool focused, AnimeSummary anime, FocusNode node, int index, int count) {
    if (!focused) {
      return;
    }
    setState(() => _selectedId = anime.id);
    if (!_restoringRetryCard) {
      _reveal(node);
    }
    if (!_restoringRetryCard && index >= count - _columns * 2) {
      _bloc.add(const SearchMoreRequested());
    }
  }

  KeyEventResult _historyKey(KeyEvent event, int index) {
    if (event.logicalKey == LogicalKeyboardKey.arrowUp && index == 0) {
      if (event is KeyDownEvent || event is KeyRepeatEvent) {
        _field.requestFocus();
      }

      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      if (event is KeyDownEvent || event is KeyRepeatEvent) {
        widget.onOpenNavigation?.call();
      }

      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  Widget _feedback(SearchState state) => TvStateView(
    icon: state.status == SearchStatus.error ? Icons.error_outline_rounded : Icons.search,
    title: switch (state.status) {
      SearchStatus.error => 'Поиск недоступен',
      SearchStatus.idle => 'Что будем смотреть?',
      _ => 'Ничего не найдено',
    },
    message: switch (state.status) {
      SearchStatus.error => state.message,
      SearchStatus.idle => null,
      _ => 'Попробуйте другое название или проверьте написание.',
    },
    autofocusAction: false,
  );

  Widget _results(SearchState state) => LayoutBuilder(
    builder: (context, constraints) {
      final tv = AppLayoutScope.isTvOf(context);
      final inset = tv
          ? CatalogLayout.horizontalInset(constraints.maxWidth)
          : AppLayoutScope.horizontalPaddingOf(context);
      final available = constraints.maxWidth - inset * 2;
      final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
      _columns = tv
          ? CatalogLayout.columnCount(constraints.maxWidth)
          : (available / (scale > 1.5 ? 220 : 160)).floor().clamp(1, 6);
      final gap = tv ? AppSpacing.lg : 12.0;
      final width = (available - (_columns - 1) * gap) / _columns;
      final selected = state.items.where((item) => item.id == _selectedId).firstOrNull ?? state.items.first;
      final account = ref.watch(authAccessProvider).canUseAccount;

      return SingleChildScrollView(
        key: const PageStorageKey('search-results'),
        controller: _scroll,
        padding: EdgeInsets.fromLTRB(inset, AppSpacing.md, inset, tv ? 64 : MediaQuery.paddingOf(context).bottom + 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              liveRegion: true,
              child: Text(
                'Результаты для «${state.query}» · ${state.items.length}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            if (tv) CatalogInspector(anime: selected),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: gap,
              runSpacing: AppSpacing.lg,
              children: [
                for (var index = 0; index < state.items.length; index++)
                  SizedBox(
                    width: width,
                    height: width / AppSizes.posterRatio,
                    child: Focus(
                      canRequestFocus: false,
                      onKeyEvent: (_, event) => _cardKey(event, index),
                      child: Builder(
                        builder: (cardContext) {
                          final anime = state.items[index];
                          final node = _cards.putIfAbsent(
                            anime.id,
                            () => FocusNode(debugLabel: 'Поиск: ${anime.title}'),
                          );

                          return MediaCard(
                            key: ValueKey('search-card-${anime.id}'),
                            focusNode: node,
                            label: anime.title,
                            caption: anime.year,
                            imageUrl: anime.posterUri?.toString(),
                            heroTag: 'anime-poster-${anime.id}',
                            onPressed: () => _openAnime(anime),
                            onLongPressed: () => unawaited(
                              showFavoriteActions(cardContext, animeId: anime.id, slug: anime.slug, title: anime.title),
                            ),
                            onFocusChanged: (focused) => _cardFocused(focused, anime, node, index, state.items.length),
                            badges: [
                              AnimeRatingBadge(rating: anime.rating),
                              if (account && anime.isFavorite == true) const AppIcon(AppIconType.heart),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
              ],
            ),
            if (state.loadingMore)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
            if (state.message case final message?) ...[
              const SizedBox(height: AppSpacing.md),
              Text(message, textAlign: TextAlign.center),
            ],
            if (state.message != null || state.loadingMore && _retry.hasFocus)
              Focus(
                canRequestFocus: false,
                onKeyEvent: _retryKey,
                child: TextButton(
                  key: const ValueKey('search-pagination-retry'),
                  focusNode: _retry,
                  onPressed: () => _bloc.add(const SearchMoreRequested(retry: true)),
                  child: Text(state.loadingMore ? 'Загружаем…' : 'Повторить загрузку'),
                ),
              ),
          ],
        ),
      );
    },
  );

  Widget _recent(SearchState state) => SingleChildScrollView(
    controller: _scroll,
    padding: const EdgeInsets.all(AppSpacing.lg),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text('Последние запросы', style: Theme.of(context).textTheme.titleLarge)),
            TextButton(onPressed: () => _bloc.add(const SearchHistoryChanged()), child: const Text('Очистить')),
          ],
        ),
        for (var index = 0; index < state.history.length; index++)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: Row(
              children: [
                Expanded(
                  child: Focus(
                    canRequestFocus: false,
                    onKeyEvent: (_, event) => _historyKey(event, index),
                    child: AppButton(
                      key: ValueKey('search-recent-$index'),
                      focusNode: _history.putIfAbsent(state.history[index], FocusNode.new),
                      variant: AppButtonVariant.neutral,
                      label: state.history[index],
                      onPressed: () => _search(state.history[index]),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                IconButton(
                  key: ValueKey('search-remove-$index'),
                  tooltip: 'Удалить запрос ${state.history[index]}',
                  onPressed: () => _bloc.add(SearchHistoryChanged(remove: state.history[index])),
                  icon: const AppIcon(AppIconType.x),
                ),
              ],
            ),
          ),
      ],
    ),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final visible = MediaQuery.viewInsetsOf(context).bottom > 0;
    if (_keyboardVisible && !visible) {
      _editing = false;
    }
    _keyboardVisible = visible;
  }

  @override
  void didUpdateWidget(covariant SearchScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _focusField());
    }
  }

  @override
  void dispose() {
    unawaited(_bloc.close());
    _query.removeListener(_inputChanged);
    _field.removeListener(_fieldChanged);
    _query.dispose();
    _field.dispose();
    _clear.dispose();
    _submit.dispose();
    _retry.dispose();
    _scroll.dispose();
    for (final node in _cards.values.followedBy(_history.values)) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tv = AppLayoutScope.isTvOf(context);

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.all(tv ? AppSpacing.lg : AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (tv) ...[
                Text('Поиск', style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: AppSpacing.md),
              ],
              Focus(
                canRequestFocus: false,
                onKeyEvent: _formKey,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Semantics(
                        label: 'Название аниме',
                        child: AppFocusBorder(
                          focusNode: _field,
                          restingColor: AppPalette.outline,
                          child: TextField(
                            key: const ValueKey('search-query'),
                            controller: _query,
                            focusNode: _field,
                            readOnly: tv && !_editing,
                            textInputAction: TextInputAction.search,
                            maxLength: 120,
                            onTap: tv ? _startEditing : null,
                            onSubmitted: (_) => _search(),
                            decoration: InputDecoration(
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              counterText: '',
                              hintText: _field.hasFocus ? null : 'Название аниме',
                              suffixIcon: IconButton(
                                key: const ValueKey('search-clear'),
                                focusNode: _clear,
                                tooltip: 'Очистить запрос',
                                onPressed: _query.text.isEmpty
                                    ? null
                                    : () {
                                        _query.clear();
                                        _field.requestFocus();
                                      },
                                icon: const AppIcon(AppIconType.x),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    AppButton(
                      key: const ValueKey('search-submit'),
                      focusNode: _submit,
                      label: 'Найти',
                      onPressed: _search,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: BlocConsumer<SearchBloc, SearchState>(
            bloc: _bloc,
            listener: _searchStateChanged,
            buildWhen: (previous, current) => previous != current,
            builder: (context, state) {
              if (state.status == SearchStatus.loading) {
                return tv ? const CatalogSkeleton() : const Center(child: CircularProgressIndicator());
              }
              if (state.items.isNotEmpty) {
                return _results(state);
              }
              if (state.status == SearchStatus.idle && state.history.isNotEmpty) {
                return _recent(state);
              }

              return _feedback(state);
            },
          ),
        ),
      ],
    );
  }
}
