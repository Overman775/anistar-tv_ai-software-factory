import 'package:app_logging/app_logging.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/repositories/catalog_repository.dart';
import 'catalog_event.dart';
import 'catalog_state.dart';

final class CatalogBloc extends Bloc<CatalogEvent, CatalogState> {
  final Logger _logger;
  final CatalogRepository _repository;
  int _loadGeneration = 0;
  int _page = 1;

  factory CatalogBloc({required CatalogRepository repository, required Logger logger}) =>
      CatalogBloc._(repository, logger);

  CatalogBloc._(this._repository, this._logger) : super(const CatalogInitial()) {
    on<CatalogStarted>(_onStarted);
    on<CatalogMoreRequested>(_onMoreRequested);
  }

  Future<void> _onMoreRequested(CatalogMoreRequested event, Emitter<CatalogState> emit) async {
    final current = state;
    if (!current.hasMore ||
        current is CatalogRefreshing ||
        current.items.isEmpty ||
        current is CatalogReady && current.isLoadingMore ||
        current is CatalogFailure && !current.isRefreshFailure && !event.retry) {
      return;
    }
    final generation = _loadGeneration;
    final currentItems = current.items;
    emit(CatalogReady(items: currentItems, hasMore: true, isLoadingMore: true));

    final result = await _repository.getPage(_page + 1);
    if (isClosed || emit.isDone || generation != _loadGeneration) {
      _logger.debugFor<CatalogBloc>('Ignored outdated page ${_page + 1} response');

      return;
    }
    result.when(
      failure: (failure) {
        _logger.errorFor<CatalogBloc>(
          'Failed to load page ${_page + 1}',
          error: failure.message,
          stackTrace: failure.stackTrace,
        );
        emit(CatalogFailure(message: failure.message, items: currentItems, hasMore: current.hasMore));
      },
      success: (nextPage) {
        _page = nextPage.page;
        final knownIds = currentItems.map((item) => item.id).toSet();
        final newItems = nextPage.items.where((item) => knownIds.add(item.id)).toList(growable: false);
        _logger.infoFor<CatalogBloc>('Loaded page ${nextPage.page}: ${newItems.length} new items');
        emit(CatalogReady(items: [...currentItems, ...newItems], hasMore: nextPage.hasNext));
      },
    );
  }

  Future<void> _onStarted(CatalogStarted event, Emitter<CatalogState> emit) async {
    if (event.preserveContent && state is CatalogRefreshing) {
      return;
    }
    final previous = state;
    final generation = ++_loadGeneration;
    if (!event.preserveContent) {
      _page = 1;
    }
    emit(
      event.preserveContent
          ? CatalogRefreshing(items: previous.items, hasMore: previous.hasMore)
          : const CatalogLoading(),
    );

    final result = await _repository.getPage(1);
    if (isClosed || emit.isDone || generation != _loadGeneration) {
      return;
    }
    result.when(
      failure: (failure) {
        emit(
          CatalogFailure(
            message: failure.message,
            items: event.preserveContent ? previous.items : const [],
            hasMore: event.preserveContent && previous.hasMore,
            isRefreshFailure: event.preserveContent,
          ),
        );
      },
      success: (page) {
        _page = page.page;
        _logger.infoFor<CatalogBloc>('Catalog loaded: ${page.items.length} items');
        emit(CatalogReady(items: page.items, hasMore: page.hasNext));
      },
    );
  }
}
