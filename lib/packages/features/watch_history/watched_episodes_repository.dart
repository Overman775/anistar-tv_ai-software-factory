import 'package:core/data.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

abstract interface class WatchedEpisodesRepository {
  Future<Result<Set<int>, Failure>> getWatched(int animeId);
  Future<Result<Set<int>, Failure>> markStarted({required int animeId, required int episodeNumber});
}

final watchedEpisodesRepositoryProvider = Provider<WatchedEpisodesRepository>(
  (ref) => throw StateError('WatchedEpisodesRepository must be supplied by the application.'),
);
