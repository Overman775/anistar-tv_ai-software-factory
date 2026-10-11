import 'package:core/data.dart';

abstract interface class WatchedEpisodesRepository {
  Future<Result<Set<int>, Failure>> getWatched(int animeId);
  Future<Result<Set<int>, Failure>> markStarted({required int animeId, required int episodeNumber});
}
