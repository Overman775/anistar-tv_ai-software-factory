import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:logger/logger.dart';

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
    if (!current.hasMore || current.items.isEmpty || current is CatalogReady && current.isLoadingMore) return;
    final generation = _loadGeneration;
    final currentItems = current.items;
    emit(CatalogReady(items: currentItems, hasMore: true, isLoadingMore: true));

    try {
      final nextPage = await _repository.getPage(_page + 1);
      if (isClosed || emit.isDone || generation != _loadGeneration) return;
      _page = nextPage.page;
      final knownIds = currentItems.map((item) => item.id).toSet();
      final newItems = nextPage.items.where((item) => knownIds.add(item.id));
      emit(CatalogReady(items: [...currentItems, ...newItems], hasMore: nextPage.hasNext));
    } on Object catch (error, stackTrace) {
      _logger.e('Catalog pagination failed', error: error, stackTrace: stackTrace);
      if (isClosed || emit.isDone || generation != _loadGeneration) return;
      emit(CatalogFailure(message: error.toString(), items: currentItems, hasMore: current.hasMore));
    }
  }

  Future<void> _onStarted(CatalogStarted event, Emitter<CatalogState> emit) async {
    final generation = ++_loadGeneration;
    emit(const CatalogLoading());
    _page = 1;

    try {
      final page = await _repository.getPage(_page);
      if (isClosed || emit.isDone || generation != _loadGeneration) return;
      _page = page.page;
      emit(CatalogReady(items: page.items, hasMore: page.hasNext));
    } on Object catch (error, stackTrace) {
      _logger.e('Catalog load failed', error: error, stackTrace: stackTrace);
      if (isClosed || emit.isDone || generation != _loadGeneration) return;
      emit(CatalogFailure(message: error.toString()));
    }
  }
}
