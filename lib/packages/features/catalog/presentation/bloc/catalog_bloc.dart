import 'package:app_logging/app_logging.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/models/anime_summary.dart';
import '../../domain/repositories/catalog_repository.dart';
import '../../domain/repositories/filtered_catalog_repository.dart';
import 'catalog_event.dart';
import 'catalog_state.dart';

final class CatalogBloc extends Bloc<CatalogEvent, CatalogState> {
  final Logger _logger;
  CatalogRepository _repository;
  int _loadGeneration = 0;
  int _page = 1;
  int? _manualRefreshGeneration;

  factory CatalogBloc({required CatalogRepository repository, required Logger logger}) =>
      CatalogBloc._(repository, logger);

  CatalogBloc._(this._repository, this._logger) : super(const CatalogInitial()) {
    on<CatalogStarted>(_onStarted);
    on<CatalogMoreRequested>(_onMoreRequested);
  }

  Future<void> _onMoreRequested(CatalogMoreRequested event, Emitter<CatalogState> emit) async {
    final current = state;
    if (event.canStart?.call() == false ||
        !current.hasMore ||
        current is CatalogRefreshing ||
        current.items.isEmpty ||
        current is CatalogReady && current.isLoadingMore ||
        current is CatalogFailure && !current.isRefreshFailure && !event.retry) {
      return;
    }
    final generation = _loadGeneration;
    final repository = _repository;
    final page = _page + 1;
    final currentItems = current.items;
    emit(CatalogReady(items: currentItems, hasMore: true, nextPageSize: current.nextPageSize, isLoadingMore: true));

    final result = await repository.getPage(page);
    if (isClosed || emit.isDone || generation != _loadGeneration) {
      _logger.debugFor<CatalogBloc>('Ignored outdated page $page response');

      return;
    }
    result.when(
      failure: (failure) {
        _logger.errorFor<CatalogBloc>(
          'Failed to load page $page',
          error: failure.message,
          stackTrace: failure.stackTrace,
        );
        emit(
          CatalogFailure(
            message: failure.message,
            items: currentItems,
            hasMore: current.hasMore,
            nextPageSize: current.nextPageSize,
          ),
        );
      },
      success: (nextPage) {
        _page = nextPage.page;
        final knownIds = currentItems.map((item) => item.id).toSet();
        final newItems = nextPage.items.where((item) => knownIds.add(item.id)).toList(growable: false);
        _logger.infoFor<CatalogBloc>('Loaded page ${nextPage.page}: ${newItems.length} new items');
        emit(
          CatalogReady(
            items: List.unmodifiable([...currentItems, ...newItems]),
            hasMore: nextPage.hasNext,
            nextPageSize: nextPage.nextPageSize,
            confirmedSort: repository is FilteredCatalogRepository ? repository.sort : null,
          ),
        );
      },
    );
  }

  Future<void> _onStarted(CatalogStarted event, Emitter<CatalogState> emit) async {
    int? manualGeneration;
    try {
      final replacement = event.repository;
      final preserveContent = event.preserveContent && replacement == null;
      final preservePages = preserveContent && event.preservePages;
      final isManualRefresh = preserveContent && !preservePages;
      if (preserveContent && _manualRefreshGeneration == _loadGeneration) return;
      if (replacement != null) {
        _repository = replacement;
      }
      final repository = _repository;
      final previous = state;
      final pageCount = preservePages ? _page : 1;
      final generation = ++_loadGeneration;
      if (isManualRefresh) {
        manualGeneration = generation;
        _manualRefreshGeneration = generation;
      }
      if (!preserveContent) {
        _page = 1;
      }
      emit(
        preserveContent
            ? CatalogRefreshing(items: previous.items, hasMore: previous.hasMore, nextPageSize: previous.nextPageSize)
            : const CatalogLoading(),
      );

      var result = await repository.getPage(1);
      final mergedItems = <AnimeSummary>[];
      final knownIds = <int>{};
      final firstPage = result.successOrNull;
      if (firstPage != null) {
        mergedItems.addAll(firstPage.items.where((item) => knownIds.add(item.id)));
      }
      for (var number = 2; number <= pageCount; number++) {
        if (isClosed || emit.isDone || generation != _loadGeneration) {
          return;
        }
        final loaded = result.successOrNull;
        if (loaded == null || !loaded.hasNext) {
          break;
        }
        result = await repository.getPage(number);
        final page = result.successOrNull;
        if (page != null) mergedItems.addAll(page.items.where((item) => knownIds.add(item.id)));
      }
      if (isClosed || emit.isDone || generation != _loadGeneration) {
        return;
      }
      result.when(
        failure: (failure) {
          emit(
            CatalogFailure(
              message: failure.message,
              items: preserveContent ? previous.items : const [],
              hasMore: preserveContent && previous.hasMore,
              nextPageSize: preserveContent ? previous.nextPageSize : null,
              isRefreshFailure: preserveContent,
            ),
          );
        },
        success: (page) {
          _page = page.page;
          _logger.infoFor<CatalogBloc>('Catalog loaded: ${mergedItems.length} items');
          emit(
            CatalogReady(
              items: List.unmodifiable(mergedItems),
              hasMore: page.hasNext,
              nextPageSize: page.nextPageSize,
              confirmedSort: repository is FilteredCatalogRepository ? repository.sort : null,
            ),
          );
        },
      );
    } finally {
      if (manualGeneration != null && _manualRefreshGeneration == manualGeneration) {
        _manualRefreshGeneration = null;
      }
      event.completion?.complete();
    }
  }
}
