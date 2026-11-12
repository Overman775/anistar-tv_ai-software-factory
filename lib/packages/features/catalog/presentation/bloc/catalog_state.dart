import 'package:flutter/foundation.dart';

import '../../domain/models/anime_summary.dart';
import '../../domain/models/catalog_sort.dart';

@immutable
sealed class CatalogState {
  final bool hasMore;
  final List<AnimeSummary> items;
  final int? nextPageSize;

  const CatalogState({this.items = const [], this.hasMore = false, this.nextPageSize});
}

@immutable
final class CatalogInitial extends CatalogState {
  const CatalogInitial();
}

@immutable
final class CatalogLoading extends CatalogState {
  const CatalogLoading();
}

@immutable
final class CatalogRefreshing extends CatalogState {
  const CatalogRefreshing({required super.items, required super.hasMore, super.nextPageSize});
}

@immutable
final class CatalogReady extends CatalogState {
  final bool isLoadingMore;
  final CatalogSort? confirmedSort;

  const CatalogReady({
    required super.items,
    required super.hasMore,
    super.nextPageSize,
    this.isLoadingMore = false,
    this.confirmedSort,
  });
}

@immutable
final class CatalogFailure extends CatalogState {
  final String message;
  final bool isRefreshFailure;

  const CatalogFailure({
    required this.message,
    super.items,
    super.hasMore,
    super.nextPageSize,
    this.isRefreshFailure = false,
  });
}
