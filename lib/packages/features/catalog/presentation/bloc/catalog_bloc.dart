import 'package:app_logging/app_logging.dart';
import 'package:core/data.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/models/anime_page.dart';
import '../../domain/repositories/catalog_repository.dart';
import 'catalog_event.dart';
import 'catalog_state.dart';

final class CatalogBloc extends Bloc<CatalogEvent, CatalogState> {
  final Logger _logger;
  CatalogRepository _repository;
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
    final repository = _repository;
    final page = _page + 1;
    final currentItems = current.items;
    emit(CatalogReady(items: currentItems, hasMore: true, isLoadingMore: true));

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
        emit(CatalogFailure(message: failure.message, items: currentItems, hasMore: current.hasMore));
      },
      success: (nextPage) {
        _page = nextPage.page;
        final knownIds = currentItems.map((item) => item.id).toSet();
        final newItems = nextPage.items.where((item) => knownIds.add(item.id)).toList(growable: false);
        _logger.infoFor<CatalogBloc>('Loaded page ${nextPage.page}: ${newItems.length} new items');
        emit(CatalogReady(items: List.unmodifiable([...currentItems, ...newItems]), hasMore: nextPage.hasNext));
      },
    );
  }

  Future<void> _onStarted(CatalogStarted event, Emitter<CatalogState> emit) async {
    final replacement = event.repository;
    final preserveContent = event.preserveContent && replacement == null;
    final preservePages = preserveContent && event.preservePages;
    if (preserveContent && !preservePages && state is CatalogRefreshing) {
      return;
    }
    if (replacement != null) {
      _repository = replacement;
    }
    final repository = _repository;
    final previous = state;
    final pageCount = preservePages ? _page : 1;
    final generation = ++_loadGeneration;
    if (!preserveContent) {
      _page = 1;
    }
    emit(
      preserveContent ? CatalogRefreshing(items: previous.items, hasMore: previous.hasMore) : const CatalogLoading(),
    );

    var result = await repository.getPage(1);
    for (var number = 2; number <= pageCount; number++) {
      if (isClosed || emit.isDone || generation != _loadGeneration) {
        return;
      }
      final loaded = result.successOrNull;
      if (loaded == null || !loaded.hasNext) {
        break;
      }
      final next = await repository.getPage(number);
      result = next.when(
        success: (page) {
          final ids = loaded.items.map((item) => item.id).toSet();

          return Result.success(
            AnimePage(
              items: [...loaded.items, ...page.items.where((item) => ids.add(item.id))],
              page: page.page,
              hasNext: page.hasNext,
            ),
          );
        },
        failure: Result.failure,
      );
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
            isRefreshFailure: preserveContent,
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
