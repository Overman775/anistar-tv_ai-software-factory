import 'package:flutter/foundation.dart';

import '../../domain/models/anime_summary.dart';

@immutable
sealed class CatalogState {
  final bool hasMore;
  final List<AnimeSummary> items;

  const CatalogState({this.items = const [], this.hasMore = false});
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
final class CatalogReady extends CatalogState {
  final bool isLoadingMore;

  const CatalogReady({required super.items, required super.hasMore, this.isLoadingMore = false});
}

@immutable
final class CatalogFailure extends CatalogState {
  final String message;

  const CatalogFailure({required this.message, super.items, super.hasMore});
}
