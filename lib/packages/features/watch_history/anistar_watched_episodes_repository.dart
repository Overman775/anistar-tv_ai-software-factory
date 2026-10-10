import 'package:anistar/anistar.dart';
import 'package:core/data.dart';
import 'package:networking/networking.dart';

import 'watched_episodes_repository.dart';

final class AnistarWatchedEpisodesRepository extends BaseRepository implements WatchedEpisodesRepository {
  final AnistarSource _source;

  AnistarWatchedEpisodesRepository(this._source, [super.logger]);

  @override
  Future<Result<Set<int>, Failure>> getWatched(int animeId) => makeApiCall(() => _source.watchedEpisodes(animeId));

  @override
  Future<Result<Set<int>, Failure>> markStarted({required int animeId, required int episodeNumber}) =>
      makeApiCall(() => _source.markWatched(animeId: animeId, episodeNumber: episodeNumber));
}
