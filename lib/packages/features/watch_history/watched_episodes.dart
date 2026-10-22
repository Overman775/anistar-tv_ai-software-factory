import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'watch_history_providers.dart';

/// The application supplies an account/origin identity; null denies account operations.
final watchHistoryAccountProvider = Provider<String?>((ref) => null);

final watchedEpisodesProvider = AsyncNotifierProvider.family<WatchedEpisodes, Set<int>, int>(
  WatchedEpisodes.new,
  retry: (_, _) => null,
);

final class WatchedEpisodes extends AsyncNotifier<Set<int>> {
  final int animeId;
  String? _account;
  int _generation = 0;
  Future<void> _pending = Future<void>.value();

  WatchedEpisodes(this.animeId);

  @override
  Future<Set<int>> build() async {
    _account = ref.watch(watchHistoryAccountProvider);
    _generation++;
    if (_account == null) {
      return const {};
    }
    final result = await ref.read(watchedEpisodesRepositoryProvider).getWatched(animeId);

    return result.when(success: Set<int>.unmodifiable, failure: (failure) => throw failure);
  }

  /// Site-confirmed writes are serialized; no device-only marks are published.
  Future<bool> markStarted(int episodeNumber) {
    final generation = _generation;
    final result = _pending.then((_) => _mark(episodeNumber, generation));
    _pending = result.then<void>((_) => Future<void>.value());

    return result;
  }

  Future<bool> _mark(int episodeNumber, int generation) async {
    try {
      if (state.isLoading && !state.hasError) {
        await future.onError((_, _) => const <int>{});
      }
      if (!ref.mounted || episodeNumber <= 0 || _account == null || generation != _generation) {
        return false;
      }
      final result = await ref
          .read(watchedEpisodesRepositoryProvider)
          .markStarted(animeId: animeId, episodeNumber: episodeNumber);
      if (!ref.mounted || generation != _generation) {
        return false;
      }

      return await result.when(
        success: (confirmed) {
          state = AsyncData(Set.unmodifiable(confirmed));

          return confirmed.contains(episodeNumber);
        },
        failure: (_) => false,
      );
    } on Object {
      return false;
    }
  }
}
