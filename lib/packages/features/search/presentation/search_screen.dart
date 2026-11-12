import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';

import '../../auth/auth_providers.dart';
import '../../catalog/domain/models/anime_summary.dart';
import '../../catalog/domain/models/catalog_filter.dart';
import '../../catalog/presentation/widgets/anime_card.dart';
import '../../catalog/presentation/widgets/catalog_inspector.dart';
import '../../catalog/presentation/widgets/catalog_layout.dart';
import '../../catalog/presentation/widgets/catalog_poster_rail.dart';
import '../../catalog/presentation/widgets/catalog_tail.dart';
import '../../favorites/favorite_catalog_status_provider.dart';
import '../../favorites/favorites_providers.dart';
import '../../favorites/presentation/favorite_actions_sheet.dart';
import '../../favorites/presentation/favorite_button.dart';
import '../domain/search_repository.dart';
import '../search_providers.dart';
import 'search_bloc.dart';
import 'search_feedback.dart';
import 'search_loading.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({
    required this.onAnimeTap,
    this.onWatchAnime,
    this.onOpenNavigation,
    this.onFilterSelected,
    this.active = true,
    super.key,
  });

  final ValueChanged<AnimeSummary> onAnimeTap;
  final ValueChanged<AnimeSummary>? onWatchAnime;
  final VoidCallback? onOpenNavigation;
  final ValueChanged<CatalogFilter>? onFilterSelected;
  final bool active;

  @override
  ConsumerState<SearchScreen> createState() => SearchScreenState();
}

class SearchScreenState extends ConsumerState<SearchScreen> {
  late SearchBloc _bloc;
  late (SearchRepository, SearchHistoryRepository) _source;
  final _query = TextEditingController();
  final _field = FocusNode(debugLabel: 'Поиск: название');
  final _clear = FocusNode(debugLabel: 'Очистить запрос');
  final _submit = FocusNode(debugLabel: 'Найти');
  final _retry = FocusNode(debugLabel: 'Повторить загрузку');
  final _watch = FocusNode(debugLabel: 'Смотреть');
  final _favorite = FocusNode(debugLabel: 'Избранное тайтла');
  final _lastGenre = FocusNode();
  bool _inspectImmediately = false;
  bool _routeCurrent = true;
  bool _returnToPoster = false;
  int? _retryCardId;
  double? _retryScrollOffset;
  bool _restoringRetryCard = false;
  final _scroll = ScrollController();
  final Map<int, FocusNode> _cards = {};
  final Map<String, FocusNode> _history = {};
  bool _editing = false;
  bool _keyboardRequestPending = false;
  bool _keyboardVisible = false;
  int? _selectedId;
  int? _pendingForward;

  bool get _resultsActive => mounted && widget.active && (ModalRoute.isCurrentOf(context) ?? true);

  @override
  void initState() {
    super.initState();
    _source = _readSource();
    _bloc = SearchBloc(_source.$1, _source.$2);
    _query.addListener(_inputChanged);
    _field.addListener(_fieldChanged);
    _scroll.addListener(_loadMore);
    _watch.addListener(_revealAction);
    _favorite.addListener(_revealAction);
    if (widget.active) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _enterSearch());
    }
  }

  void _inputChanged() => setState(() => _retryCardId = null);
  void _fieldChanged() {
    setState(() => _editing = _field.hasFocus && _editing);
  }

  (SearchRepository, SearchHistoryRepository) _readSource() =>
      (ref.read(searchRepositoryProvider), ref.read(searchHistoryRepositoryProvider));

  void _sourceChanged() {
    final source = _readSource();
    if (source == _source) return;
    unawaited(_bloc.close());
    setState(() {
      _source = source;
      _bloc = SearchBloc(source.$1, source.$2);
      _query.clear();
      _selectedId = null;
      _inspectImmediately = false;
      _returnToPoster = false;
      _pendingForward = null;
      _retryScrollOffset = null;
    });
  }

  void focusFirst() {
    final selected = _cards[_selectedId];
    if (!_editing && widget.active && ModalRoute.isCurrentOf(context) != false && selected?.context != null) {
      selected?.requestFocus();
    } else {
      _focusField();
    }
  }

  void _enterSearch() {
    if (!mounted || !widget.active || ModalRoute.of(context)?.isCurrent != true) return;
    if (AppLayoutScope.isTvOf(context) && _bloc.state.items.any((item) => item.id == _selectedId)) {
      focusFirst();

      return;
    }
    _startEditing();
  }

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
    if (mounted && widget.active && ModalRoute.of(context)?.isCurrent == true) {
      if (_field.hasFocus) {
        _field.requestFocus();
      } else {
        final focusScope = FocusScope.of(context);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted &&
              !_editing &&
              widget.active &&
              ModalRoute.of(context)?.isCurrent == true &&
              identical(FocusManager.instance.primaryFocus, focusScope) &&
              !_field.hasFocus) {
            _field.requestFocus();
          }
        });
      }
    }

    return true;
  }

  void _startEditing() {
    if (_editing) return;
    setState(() => _editing = true);
    if (!_field.hasPrimaryFocus) {
      _field.requestFocus();

      return;
    }

    // Opening an already focused read-only field does not generate a focus
    // change. Request its keyboard once the editable field has rebuilt.
    _keyboardRequestPending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _keyboardRequestPending = false;
      if (!mounted ||
          !_editing ||
          !widget.active ||
          !_field.hasPrimaryFocus ||
          ModalRoute.of(context)?.isCurrent != true) {
        return;
      }
      _field.context?.findAncestorStateOfType<EditableTextState>()?.requestKeyboard();
    });
  }

  void _search([String? query]) {
    if (!widget.active || ModalRoute.isCurrentOf(context) == false) return;
    if (query != null) {
      _query.text = query;
    }
    finishEditing();
    _field.requestFocus();
    _selectedId = null;
    _inspectImmediately = false;
    _pendingForward = null;
    if (_scroll.hasClients) {
      _scroll.jumpTo(0);
    }
    _bloc.add(SearchSubmitted(_query.text));
  }

  void _loadMore() {
    if (_resultsActive &&
        _scroll.hasClients &&
        _scroll.position.axis == Axis.vertical &&
        _scroll.position.extentAfter < 400) {
      _bloc.add(const SearchMoreRequested());
    }
  }

  void _focusBody() {
    final state = _bloc.state;
    final items = state.items;
    if (items.isNotEmpty) {
      if (AppLayoutScope.isTvOf(context)) {
        final index = items.indexWhere((item) => item.id == _selectedId);
        _focusRailCard(items, index < 0 ? 0 : index, CatalogPosterRail.stepOf(context));
      } else {
        _cards[items.first.id]?.requestFocus();
      }
    } else if (state.history.isNotEmpty && (state.status == SearchStatus.idle || _validationMessage(state) != null)) {
      _history[state.history.first]?.requestFocus();
    } else {
      _submit.requestFocus();
    }
  }

  KeyEventResult _formKey(FocusNode node, KeyEvent event) {
    if (!AppLayoutScope.isTvOf(context)) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (_editing &&
        (!_keyboardRequestPending || key == LogicalKeyboardKey.escape || key == LogicalKeyboardKey.goBack)) {
      if (key == LogicalKeyboardKey.arrowDown) {
        if (event is KeyDownEvent) {
          finishEditing();
          _focusBody();
        }

        return KeyEventResult.handled;
      }
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
      final nodes = [_field, if (_query.text.isNotEmpty) _clear, _submit];
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

  FocusNode _cardFocus(AnimeSummary anime) =>
      _cards.putIfAbsent(anime.id, () => FocusNode(debugLabel: 'Поиск: ${anime.title}'));

  void _focusRailCard(List<AnimeSummary> items, int index, double step) {
    final anime = items[index];
    _selectRailCard(anime, index, step);
    _cardFocus(anime).requestFocus();
  }

  void _selectRailCard(AnimeSummary anime, int index, double step) {
    if (_selectedId == anime.id) return;
    setState(() {
      _selectedId = anime.id;
      _inspectImmediately = false;
    });
    _scrollRailTo(index, step);
  }

  void _scrollRailTo(int index, double step) {
    if (!_scroll.hasClients) return;
    final position = _scroll.position;
    final target = (index * step).clamp(position.minScrollExtent, position.maxScrollExtent);
    final duration = AppMotion.durationOf(context, CatalogLayout.railMotion);
    if (duration == Duration.zero) {
      _scroll.jumpTo(target);
    } else if (target != position.pixels || position.isScrollingNotifier.value) {
      unawaited(_scroll.animateTo(target, duration: duration, curve: Curves.easeOutCubic));
    }
  }

  KeyEventResult _railKey(KeyEvent event, double step) {
    final key = event.logicalKey;
    final state = _bloc.state;
    final items = state.items;
    final focused = FocusManager.instance.primaryFocus;
    if (focused == _retry) return _retryKey(event);
    final index = items.indexWhere((item) => _cards[item.id] == focused);
    if (index < 0 ||
        (key != LogicalKeyboardKey.arrowUp &&
            key != LogicalKeyboardKey.arrowDown &&
            key != LogicalKeyboardKey.arrowLeft &&
            key != LogicalKeyboardKey.arrowRight)) {
      return KeyEventResult.ignored;
    }
    if (event is KeyDownEvent || event is KeyRepeatEvent) {
      if (key == LogicalKeyboardKey.arrowUp) {
        _pendingForward = null;
        _focusWatch();
      } else if (key == LogicalKeyboardKey.arrowLeft) {
        if (index == 0) {
          widget.onOpenNavigation?.call();
        } else {
          _focusRailCard(items, index - 1, step);
        }
      } else if (key == LogicalKeyboardKey.arrowRight) {
        if (index + 1 < items.length) {
          _focusRailCard(items, index + 1, step);
        } else if (state.message != null) {
          _retryCardId = items[index].id;
          _retryScrollOffset = _scroll.hasClients ? _scroll.offset : null;
          _retry.requestFocus();
          _scrollRailTo(items.length, step);
        } else if (state.hasMore) {
          _pendingForward = items[index].id;
        }
      }
    }

    return KeyEventResult.handled;
  }

  void _focusWatch() {
    final selected = _selectedId;
    setState(() => _inspectImmediately = true);
    if (_watch.canRequestFocus) {
      _watch.requestFocus();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_resultsActive && _inspectImmediately && _selectedId == selected) _watch.requestFocus();
      });
    }
  }

  void _revealAction() {
    final node = _watch.hasFocus ? _watch : _favorite;
    if (!node.hasFocus) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (node.context case final target? when _resultsActive && node.hasFocus) {
        unawaited(Scrollable.ensureVisible(target, duration: AppMotion.durationOf(target, AppMotion.fast)));
      }
    });
  }

  KeyEventResult _actionKey(KeyEvent event) {
    final key = event.logicalKey;
    if (key != LogicalKeyboardKey.arrowDown &&
        key != LogicalKeyboardKey.arrowUp &&
        key != LogicalKeyboardKey.arrowLeft &&
        key != LogicalKeyboardKey.arrowRight) {
      return KeyEventResult.ignored;
    }
    if (event is KeyDownEvent || event is KeyRepeatEvent) {
      if (key == LogicalKeyboardKey.arrowDown) {
        _focusBody();
      } else if (key == LogicalKeyboardKey.arrowUp) {
        (_lastGenre.context != null && _lastGenre.canRequestFocus ? _lastGenre : _field).requestFocus();
      } else if (key == LogicalKeyboardKey.arrowLeft && _favorite.hasFocus) {
        _watch.requestFocus();
      } else if (key == LogicalKeyboardKey.arrowRight && _favorite.context != null && _favorite.canRequestFocus) {
        _favorite.requestFocus();
      }
    }

    return KeyEventResult.handled;
  }

  KeyEventResult _retryKey(KeyEvent event) {
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
    if (!_resultsActive) return;
    if (_retry.hasFocus && state.status == SearchStatus.ready && !state.loadingMore && state.message == null) {
      _restoreRetryCard();
    }
    final pending = _pendingForward;
    if (pending == null) return;
    final index = state.items.indexWhere((item) => item.id == pending);
    if (index < 0 || state.message != null || index == state.items.length - 1 && !state.hasMore) {
      _pendingForward = null;

      return;
    }
    final next = state.items.elementAtOrNull(index + 1);
    if (next == null) return;
    final bloc = _bloc;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_resultsActive || bloc != _bloc || _pendingForward != pending || _cards[pending]?.hasPrimaryFocus != true) {
        return;
      }
      _pendingForward = null;
      final items = bloc.state.items;
      if (items.elementAtOrNull(index + 1)?.id != next.id) return;
      _focusRailCard(items, index + 1, CatalogPosterRail.stepOf(context));
    });
  }

  void _openAnime(AnimeSummary anime, {bool watch = false}) {
    _pendingForward = null;
    _selectedId = anime.id;
    final open = watch ? widget.onWatchAnime ?? widget.onAnimeTap : widget.onAnimeTap;
    open(anime);
  }

  void _watchSelected() {
    if (!_resultsActive) return;
    final items = _bloc.state.items;
    final selected = items.where((item) => item.id == _selectedId).firstOrNull ?? items.firstOrNull;
    if (selected == null) return;
    _returnToPoster = true;
    _openAnime(selected, watch: true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_resultsActive) _returnToPoster = false;
    });
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

  String? _validationMessage(SearchState state) => state.error == SearchError.validation ? state.message : null;

  Widget _feedback(SearchState state) => SearchFeedback(
    icon: state.status == SearchStatus.error ? Icons.error_outline_rounded : Icons.search,
    title: switch (state.status) {
      SearchStatus.error => 'Поиск недоступен',
      SearchStatus.idle => 'Что будем смотреть?',
      _ => 'Ничего не найдено',
    },
    message: switch (state.status) {
      SearchStatus.error => state.message ?? 'Не удалось загрузить результаты. Попробуйте ещё раз.',
      SearchStatus.idle => null,
      _ => 'Попробуйте другое название или проверьте написание.',
    },
  );

  Widget _resultCount(BuildContext context, SearchState state) => Semantics(
    liveRegion: true,
    child: Text(
      'Результаты для «${state.query}» · Найдено: ${state.items.length}',
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppPalette.textSecondary),
    ),
  );

  Widget _tvResults(SearchState state) {
    final selected = state.items.where((item) => item.id == _selectedId).firstOrNull ?? state.items.first;
    final canUseAccount = ref.watch(authAccessProvider).canUseAccount;
    final favorites = ref.watch(favoritesControllerProvider);
    final favoriteIds = watchFavoriteMembership(ref, state.items, active: _resultsActive && canUseAccount);
    final failure = state.message;
    final bloc = _bloc;
    final retryVisible = failure != null || state.loadingMore && _retry.hasFocus;
    final hasSlots = state.hasMore && !retryVisible;

    return CatalogInspector(
      anime: selected,
      immediate: _inspectImmediately,
      lastGenreFocus: _lastGenre,
      onGenreTap: widget.onFilterSelected == null
          ? null
          : (anime, filter) {
              if (_resultsActive &&
                  (state.items.where((item) => item.id == _selectedId).firstOrNull ?? state.items.first).id ==
                      anime.id) {
                widget.onFilterSelected?.call(filter);
              }
            },
      onGenreTop: (_) => _field.requestFocus(),
      onGenreBottom: _watch.requestFocus,
      actions: _inspectorActions(
        selected,
        canUseAccount,
        favorites.confirmedStatus(
          selected.id,
          reported: selected.isFavorite,
          listed: favoriteIds.contains(selected.id),
        ),
      ),
      rail: CatalogPosterRail(
        controller: _scroll,
        heading: _resultCount(context, state),
        items: state.items,
        selectedId: selected.id,
        active: _resultsActive,
        loadingMore: state.loadingMore,
        unloadedCount: hasSlots ? CatalogLayout.defaultPageSize : 0,
        continuationIdentity: hasSlots ? state : null,
        onVisibleContinuation: () {
          if (_resultsActive && bloc == _bloc && identical(state, bloc.state)) {
            bloc.add(const SearchMoreRequested());
          }
        },
        tail: retryVisible
            ? CatalogTail(
                key: const ValueKey('search-pagination-retry'),
                error: state.loadingMore ? 'Загружаем…' : failure,
                retrying: state.loadingMore,
                onRetry: () => bloc.add(const SearchMoreRequested(retry: true)),
                focusNode: _retry,
              )
            : null,
        onKeyEvent: _railKey,
        itemBuilder: (context, anime, index, step) => AnimeCard(
          key: ValueKey('search-card-${anime.id}'),
          anime: anime,
          rail: true,
          selected: anime.id == selected.id,
          isFavorite: favorites.confirmedStatus(
            anime.id,
            reported: anime.isFavorite,
            listed: favoriteIds.contains(anime.id),
          ),
          showFavorite: canUseAccount,
          focusNode: _cardFocus(anime),
          onFocusChanged: (focused) {
            if (!focused) {
              if (_pendingForward == anime.id) _pendingForward = null;
            } else if (_resultsActive && !_restoringRetryCard) {
              _selectRailCard(anime, index, step);
            }
          },
          onTap: () {
            _selectRailCard(anime, index, step);
            _openAnime(anime);
          },
          onLongPressed: () =>
              unawaited(showFavoriteActions(context, animeId: anime.id, slug: anime.slug, title: anime.title)),
        ),
      ),
    );
  }

  Widget _inspectorActions(AnimeSummary anime, bool account, bool? favorite) => Focus(
    canRequestFocus: false,
    onKeyEvent: (_, event) => _actionKey(event),
    child: Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        AppButton(
          label: 'Смотреть',
          focusNode: _watch,
          minHeight: CatalogLayout.inspectorActionMinHeight,
          icon: const AppIcon(AppIconType.play, size: 20),
          onPressed: _watchSelected,
        ),
        if (account)
          FavoriteButton(
            animeId: anime.id,
            slug: anime.slug,
            initialFavorite: favorite,
            focusNode: _favorite,
            minHeight: CatalogLayout.inspectorActionMinHeight,
          ),
      ],
    ),
  );

  Widget _mobileResults(SearchState state) => LayoutBuilder(
    builder: (context, constraints) {
      final inset = AppLayoutScope.horizontalPaddingOf(context);
      final available = constraints.maxWidth - inset * 2;
      final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
      final columns = CatalogLayout.mobileColumnCount(
        available,
        scale,
        landscape: MediaQuery.orientationOf(context) == Orientation.landscape,
      );
      const gap = CatalogLayout.mobilePosterGap;
      final width = (available - (columns - 1) * gap) / columns;
      final account = ref.watch(authAccessProvider).canUseAccount;
      final favorites = ref.watch(favoritesControllerProvider);
      final favoriteIds = watchFavoriteMembership(ref, state.items, active: _resultsActive && account);

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(inset, AppSpacing.sm, inset, AppSpacing.md),
            child: _resultCount(context, state),
          ),
          Expanded(
            child: SingleChildScrollView(
              key: const PageStorageKey('search-results'),
              controller: _scroll,
              padding: EdgeInsets.fromLTRB(inset, 0, inset, MediaQuery.paddingOf(context).bottom + 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                    spacing: gap,
                    runSpacing: AppSpacing.lg,
                    children: [
                      for (final anime in state.items)
                        SizedBox(
                          width: width,
                          height: width / AppSizes.posterRatio,
                          child: Builder(
                            builder: (cardContext) => MediaCard(
                              key: ValueKey('search-card-${anime.id}'),
                              focusNode: _cardFocus(anime),
                              label: anime.title,
                              showCaption: false,
                              showBookmark:
                                  account &&
                                  favorites.confirmedStatus(
                                        anime.id,
                                        reported: anime.isFavorite,
                                        listed: favoriteIds.contains(anime.id),
                                      ) ==
                                      true,
                              imageUrl: anime.posterUri?.toString(),
                              heroTag: 'anime-poster-${anime.id}',
                              onPressed: () => _openAnime(anime),
                              onLongPressed: () => unawaited(
                                showFavoriteActions(
                                  cardContext,
                                  animeId: anime.id,
                                  slug: anime.slug,
                                  title: anime.title,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (state.loadingMore)
                    const Padding(
                      padding: EdgeInsets.all(AppSpacing.lg),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  if (state.message case final message?) ...[
                    const SizedBox(height: AppSpacing.md),
                    Text(message, textAlign: TextAlign.center),
                    TextButton(
                      key: const ValueKey('search-pagination-retry'),
                      onPressed: () => _bloc.add(const SearchMoreRequested(retry: true)),
                      child: const Text('Повторить загрузку'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      );
    },
  );

  Widget _recentHeader(BuildContext context) {
    final title = Text('Последние запросы', style: Theme.of(context).textTheme.titleLarge);
    final clear = TextButton(onPressed: () => _bloc.add(const SearchHistoryChanged()), child: const Text('Очистить'));
    if (!AppLayoutScope.isTvOf(context) && MediaQuery.textScalerOf(context).scale(16) > 16) {
      return OverflowBar(
        alignment: MainAxisAlignment.spaceBetween,
        overflowSpacing: AppSpacing.xs,
        children: [title, clear],
      );
    }

    return Row(
      children: [
        Expanded(child: title),
        clear,
      ],
    );
  }

  Widget _recent(SearchState state) => SingleChildScrollView(
    controller: _scroll,
    padding: const EdgeInsets.all(AppSpacing.lg),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _recentHeader(context),
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
    final wasCurrent = _routeCurrent;
    _routeCurrent = ModalRoute.isCurrentOf(context) ?? true;
    if (!_routeCurrent) _pendingForward = null;
    if (_routeCurrent && !wasCurrent && _returnToPoster) {
      _returnToPoster = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_resultsActive) focusFirst();
      });
    }
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
      WidgetsBinding.instance.addPostFrameCallback((_) => _enterSearch());
    } else if (!widget.active && oldWidget.active) {
      _pendingForward = null;
      _bloc.add(const SearchSuspended());
      if (_editing) {
        _editing = false;
        unawaited(SystemChannels.textInput.invokeMethod<void>('TextInput.hide'));
      }
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
    _watch.dispose();
    _favorite.dispose();
    _lastGenre.dispose();
    _scroll.dispose();
    for (final node in _cards.values.followedBy(_history.values)) {
      node.dispose();
    }
    super.dispose();
  }

  Widget _searchForm(bool tv) => BlocBuilder<SearchBloc, SearchState>(
    bloc: _bloc,
    buildWhen: (previous, current) => _validationMessage(previous) != _validationMessage(current),
    builder: (context, state) {
      final message = _validationMessage(state);
      final height = tv ? AppSizes.tvControl : AppSizes.touchControl;
      final fieldStyle = Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: 16);

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: AppSpacing.sm,
        children: [
          Focus(
            canRequestFocus: false,
            onKeyEvent: _formKey,
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: AppSpacing.sm,
                children: [
                  Expanded(
                    child: Semantics(
                      label: 'Название аниме',
                      child: AppInputFrame(
                        focusNode: _field,
                        hasError: message != null,
                        child: TextField(
                          key: const ValueKey('search-query'),
                          controller: _query,
                          focusNode: _field,
                          readOnly: tv && !_editing,
                          style: fieldStyle,
                          textAlignVertical: TextAlignVertical.center,
                          textInputAction: TextInputAction.search,
                          onTap: tv ? _startEditing : null,
                          onSubmitted: (_) => _search(),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
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
                              icon: const AppIcon(AppIconType.x, size: 20),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  AppButton(
                    key: const ValueKey('search-submit'),
                    focusNode: _submit,
                    icon: const AppIcon(AppIconType.search, size: 20),
                    label: 'Найти',
                    minHeight: height,
                    onPressed: _search,
                  ),
                ],
              ),
            ),
          ),
          if (message != null)
            Semantics(
              liveRegion: true,
              child: Text(message, style: const TextStyle(color: AppPalette.danger)),
            ),
        ],
      );
    },
  );

  @override
  Widget build(BuildContext context) {
    ref
      ..listen(searchRepositoryProvider, (_, _) => _sourceChanged())
      ..listen(searchHistoryRepositoryProvider, (_, _) => _sourceChanged());
    final tv = AppLayoutScope.isTvOf(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = !tv && constraints.maxHeight < 160;
        var formInset = tv ? AppSpacing.lg : AppSpacing.md;
        if (compact) formInset = AppSpacing.xs;
        final form = Padding(
          padding: EdgeInsets.all(formInset),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (tv) ...[
                Text('Поиск', style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: AppSpacing.md),
              ],
              _searchForm(tv),
            ],
          ),
        );
        return Column(
          children: [
            if (tv)
              form
            else
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: constraints.maxHeight),
                child: SingleChildScrollView(primary: false, child: form),
              ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, resultsConstraints) => BlocConsumer<SearchBloc, SearchState>(
                  bloc: _bloc,
                  listener: _searchStateChanged,
                  buildWhen: (previous, current) => previous != current,
                  builder: (context, state) {
                    if (compact && resultsConstraints.maxHeight < 100) {
                      return const SizedBox.shrink();
                    }
                    if (state.status == SearchStatus.loading) {
                      return const SearchLoading();
                    }
                    if (state.items.isNotEmpty) {
                      return tv ? _tvResults(state) : _mobileResults(state);
                    }
                    if (_validationMessage(state) != null) {
                      return state.history.isNotEmpty ? _recent(state) : _feedback(const SearchState());
                    }
                    if (state.status == SearchStatus.idle && state.history.isNotEmpty) {
                      return _recent(state);
                    }

                    return _feedback(state);
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
