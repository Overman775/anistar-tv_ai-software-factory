import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../catalog/domain/models/anime_summary.dart';
import 'favorites_providers.dart';

/// Positive membership from successfully read pages for one account revision.
final favoriteCatalogStatusProvider = StreamProvider.autoDispose.family<Set<int>, (String, int)>((ref, scope) async* {
  final repository = ref.watch(favoritesRepositoryProvider);
  final ids = <int>{};
  var page = 1;
  bool isCurrent() =>
      ref.mounted &&
      ref.read(favoritesAccountProvider) == scope.$1 &&
      ref.read(favoritesControllerProvider).revision == scope.$2;

  while (isCurrent()) {
    final result = await repository.getPage(page);
    if (!isCurrent()) return;
    final data = result.successOrNull;
    if (data == null) return;
    ids.addAll(data.items.map((anime) => anime.id));
    yield Set.unmodifiable(ids);
    if (!data.hasNext) return;
    page++;
  }
});

/// Read positive site membership once for active surfaces with unknown cards.
Set<int> watchFavoriteMembership(WidgetRef ref, Iterable<AnimeSummary> items, {required bool active}) {
  final account = ref.watch(favoritesAccountProvider);
  final state = ref.watch(favoritesControllerProvider);
  if (!active ||
      account == null ||
      !items.any((anime) => state.confirmedStatus(anime.id, reported: anime.isFavorite) == null)) {
    return const {};
  }

  return ref.watch(favoriteCatalogStatusProvider((account, state.revision))).asData?.value ?? const {};
}
