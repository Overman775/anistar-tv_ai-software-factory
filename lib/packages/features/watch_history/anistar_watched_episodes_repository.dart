import 'package:anistar/anistar.dart';
import 'package:core/data.dart';
import 'package:networking/networking.dart';

import 'watched_episodes_repository.dart';

final class AnistarWatchedEpisodesRepository extends BaseRepository implements WatchedEpisodesRepository {
  final AnistarClient _client;

  AnistarWatchedEpisodesRepository(this._client, [super.logger]);

  @override
  Future<Result<Set<int>, Failure>> getWatched(int animeId) => makeApiCall(() => _client.watchedEpisodes(animeId));

  @override
  Future<Result<Set<int>, Failure>> markStarted({required int animeId, required int episodeNumber}) =>
      makeApiCall(() => _client.markWatched(animeId: animeId, episodeNumber: episodeNumber));
}
