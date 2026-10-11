import 'dart:async';

import 'package:anistar_tv/packages/features/watch_history/domain/repositories/watched_episodes_repository.dart';
import 'package:core/data.dart';
import 'package:networking/networking.dart';

final class FakeWatchedEpisodesRepository implements WatchedEpisodesRepository {
  final Map<int, Set<int>> watched = {};
  int writes = 0;
  bool failRead = false;
  bool failWrite = false;
  Completer<void>? writeGate;

  @override
  Future<Result<Set<int>, Failure>> getWatched(int animeId) async => failRead
      ? const Result.failure(RequestFailure(message: 'Read rejected'))
      : Result.success({...?watched[animeId]});

  @override
  Future<Result<Set<int>, Failure>> markStarted({required int animeId, required int episodeNumber}) async {
    if (watched[animeId]?.contains(episodeNumber) == true) {
      return Result.success({...watched[animeId]!});
    }
    writes++;
    await writeGate?.future;
    if (failWrite) {
      return const Result.failure(RequestFailure(message: 'Mark rejected'));
    }
    final confirmed = watched.putIfAbsent(animeId, () => {})..add(episodeNumber);

    return Result.success({...confirmed});
  }
}
