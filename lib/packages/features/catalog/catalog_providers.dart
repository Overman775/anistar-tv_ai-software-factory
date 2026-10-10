import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'domain/models/catalog_filter.dart';
import 'domain/repositories/catalog_browse_repository.dart';
import 'domain/repositories/catalog_repository.dart';

final catalogRepositoryProvider = Provider<CatalogRepository>(
  (ref) => throw StateError('CatalogRepository must be supplied by the application.'),
);

final catalogBrowseRepositoryProvider = Provider<CatalogBrowseRepository>(
  (ref) => throw StateError('CatalogBrowseRepository must be supplied by the application.'),
);

final genresProvider = FutureProvider<List<CatalogFilter>>(retry: (_, _) => null, (ref) async {
  final result = await ref.watch(catalogBrowseRepositoryProvider).getGenres();

  return result.when(success: (items) => items, failure: (failure) => throw failure);
});
