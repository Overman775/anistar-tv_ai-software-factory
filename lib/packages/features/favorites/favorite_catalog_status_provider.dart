import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'favorites_repository_provider.dart';

/// Positive membership from successfully read pages for one account revision.
final favoriteCatalogStatusProvider = StreamProvider.autoDispose.family<Set<int>, (String, int)>((ref, scope) async* {
  final repository = ref.watch(favoritesRepositoryProvider);
  final ids = <int>{};
  var page = 1;
  while (ref.mounted && ref.read(favoritesAccountProvider) == scope.$1) {
    final result = await repository.getPage(page);
    if (!ref.mounted || ref.read(favoritesAccountProvider) != scope.$1) return;
    final data = result.successOrNull;
    if (data == null) return;
    ids.addAll(data.items.map((anime) => anime.id));
    yield Set.unmodifiable(ids);
    if (!data.hasNext) return;
    page++;
  }
});
