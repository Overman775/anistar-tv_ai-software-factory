import 'dart:async';

import 'package:core/data.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../catalog/domain/models/anime_summary.dart';
import '../domain/search_repository.dart';
import '../domain/search_rules.dart';

final class SearchBloc extends Bloc<SearchEvent, SearchState> {
  final SearchRepository _repository;
  final SearchHistoryRepository _history;
  RequestCancellation? _cancellation;
  int _generation = 0;
  bool _historyChanged = false;
  Future<void> _historyWrites = Future<void>.value();

  SearchBloc(this._repository, this._history) : super(const SearchState()) {
    on<SearchSubmitted>(_submit);
    on<SearchMoreRequested>(_more);
    on<SearchHistoryChanged>(_changeHistory);
    on<_HistoryLoaded>((event, emit) {
      if (!_historyChanged) {
        emit(_copy(history: event.queries, message: state.message));
      }
    });
    unawaited(_loadHistory());
  }

  @override
  Future<void> close() {
    _generation++;
    _cancellation?.cancel();

    return super.close();
  }

  Future<void> _loadHistory() async {
    final result = await _history.read();
    if (!isClosed) {
      add(_HistoryLoaded(result.successOrNull ?? const []));
    }
  }

  SearchState _copy({List<String>? history, bool? loadingMore, String? message, SearchError? error}) => SearchState(
    query: state.query,
    status: state.status,
    items: state.items,
    history: history ?? state.history,
    page: state.page,
    hasMore: state.hasMore,
    loadingMore: loadingMore ?? state.loadingMore,
    message: message,
    error: error ?? state.error,
  );

  Future<void> _submit(SearchSubmitted event, Emitter<SearchState> emit) async {
    final query = event.query.trim();
    final generation = ++_generation;
    _cancellation?.cancel();
    final cancellation = _cancellation = RequestCancellation();
    if (query.isEmpty || !SearchRules.hasValidQueryLength(query)) {
      emit(
        SearchState(
          query: query,
          status: query.isEmpty ? SearchStatus.ready : SearchStatus.error,
          history: state.history,
          message: switch (SearchRules.queryLength(query)) {
            0 => null,
            < SearchRules.minimumQueryLength => 'Введите не менее 4 символов.',
            _ => 'Введите не более 120 символов.',
          },
          error: query.isEmpty ? null : SearchError.validation,
        ),
      );

      return;
    }
    final history = [
      query,
      ...state.history.where((value) => normalizeSearchQuery(value) != normalizeSearchQuery(query)),
    ].take(SearchRules.historyLimit).toList(growable: false);
    _historyChanged = true;
    emit(SearchState(query: query, status: SearchStatus.loading, history: List.unmodifiable(history)));
    _saveHistory(history);
    final result = await _repository.search(query, cancellation: cancellation);
    if (isClosed || generation != _generation || cancellation.isCancelled) {
      return;
    }
    result.when(
      success: (page) => emit(
        SearchState(
          query: query,
          status: SearchStatus.ready,
          items: List.unmodifiable(page.items),
          history: state.history,
          page: 1,
          hasMore: page.hasNext,
        ),
      ),
      failure: (failure) => emit(
        SearchState(
          query: query,
          status: SearchStatus.error,
          history: state.history,
          message: failure.message,
          error: SearchError.request,
        ),
      ),
    );
  }

  Future<void> _more(SearchMoreRequested event, Emitter<SearchState> emit) async {
    if (state.status != SearchStatus.ready ||
        state.items.isEmpty ||
        !state.hasMore ||
        state.loadingMore ||
        state.message != null && !event.retry) {
      return;
    }
    final generation = _generation;
    final query = state.query;
    final nextPage = state.page + 1;
    final cancellation = _cancellation;
    emit(_copy(loadingMore: true));
    final result = await _repository.search(query, page: nextPage, cancellation: cancellation);
    if (isClosed || generation != _generation || cancellation?.isCancelled == true) {
      return;
    }
    result.when(
      success: (page) {
        final ids = state.items.map((item) => item.id).toSet();
        emit(
          SearchState(
            query: query,
            status: SearchStatus.ready,
            items: List.unmodifiable([...state.items, ...page.items.where((item) => ids.add(item.id))]),
            history: state.history,
            page: nextPage,
            hasMore: page.hasNext,
          ),
        );
      },
      failure: (failure) => emit(_copy(loadingMore: false, message: failure.message)),
    );
  }

  void _changeHistory(SearchHistoryChanged event, Emitter<SearchState> emit) {
    _historyChanged = true;
    final history = event.remove == null
        ? <String>[]
        : state.history.where((value) => value != event.remove).toList(growable: false);
    emit(_copy(history: List.unmodifiable(history), message: state.message));
    _saveHistory(history);
  }

  void _saveHistory(List<String> history) {
    _historyWrites = _historyWrites.then((_) async {
      await _history.save(List.unmodifiable(history));
    });
  }
}

@immutable
sealed class SearchEvent {
  const SearchEvent();
}

@immutable
final class SearchSubmitted extends SearchEvent {
  final String query;
  const SearchSubmitted(this.query);
}

@immutable
final class SearchMoreRequested extends SearchEvent {
  final bool retry;
  const SearchMoreRequested({this.retry = false});
}

@immutable
final class SearchHistoryChanged extends SearchEvent {
  final String? remove;
  const SearchHistoryChanged({this.remove});
}

@immutable
final class _HistoryLoaded extends SearchEvent {
  final List<String> queries;
  const _HistoryLoaded(this.queries);
}

enum SearchStatus { idle, loading, ready, error }

enum SearchError { validation, request }

@immutable
final class SearchState {
  final String query;
  final SearchStatus status;
  final List<AnimeSummary> items;
  final List<String> history;
  final int page;
  final bool hasMore;
  final bool loadingMore;
  final String? message;
  final SearchError? error;

  const SearchState({
    this.query = '',
    this.status = SearchStatus.idle,
    this.items = const [],
    this.history = const [],
    this.page = 0,
    this.hasMore = false,
    this.loadingMore = false,
    this.message,
    this.error,
  });
}
