import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:storage/providers.dart';

/// The application supplies the signed-in account, independent of mirror origin.
final watchHistoryAccountProvider = Provider<String?>((ref) => null);

final watchedEpisodesProvider = AsyncNotifierProvider.family<WatchedEpisodes, Set<int>, int>(WatchedEpisodes.new);

final class WatchedEpisodes extends AsyncNotifier<Set<int>> {
  final int animeId;
  String? _key;
  Future<void> _pending = Future<void>.value();

  WatchedEpisodes(this.animeId);

  @override
  Future<Set<int>> build() async {
    final account = ref.watch(watchHistoryAccountProvider);
    _key = account == null ? null : 'anistar.watched.v1.${Uri.encodeComponent(account)}.$animeId';
    final key = _key;
    if (key == null) {
      return const {};
    }
    final values = await ref.read(sharedPreferencesStorageProvider).get<List<String>>(key, const []);

    return Set.unmodifiable(values.map(int.tryParse).whereType<int>().where((number) => number > 0));
  }

  /// Serializes writes so simultaneous starts cannot replace each other's marks.
  /// A failed read/write leaves the previous persisted history intact.
  Future<bool> markStarted(int episodeNumber) {
    final key = _key;
    final result = _pending.then((_) => _mark(episodeNumber, key));
    _pending = result.then<void>((_) => Future<void>.value());

    return result;
  }

  Future<bool> _mark(int episodeNumber, String? key) async {
    try {
      await future;
      if (!ref.mounted || episodeNumber <= 0 || key == null || key != _key) {
        return false;
      }
      final current = state.requireValue;
      if (current.contains(episodeNumber)) {
        return true;
      }
      final next = {...current, episodeNumber};
      final values = next.toList()..sort();
      await ref.read(sharedPreferencesStorageProvider).set(key, values.map((number) => '$number').toList());
      if (ref.mounted && key == _key) {
        state = AsyncData(Set.unmodifiable(next));
      }

      return true;
    } on Object {
      return false;
    }
  }
}
