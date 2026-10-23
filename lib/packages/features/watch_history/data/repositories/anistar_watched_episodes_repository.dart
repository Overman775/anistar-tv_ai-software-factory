import 'package:anistar/anistar.dart';
import 'package:core/data.dart';
import 'package:networking/networking.dart';

import '../../../common/data/anistar_errors.dart';
import '../../domain/repositories/watched_episodes_repository.dart';

final class AnistarWatchedEpisodesRepository extends BaseRepository implements WatchedEpisodesRepository {
  final AnistarClient _client;
  final String? Function() _account;

  AnistarWatchedEpisodesRepository(this._client, [super.logger, String? Function()? account])
    : _account = account ?? (() => null);

  @override
  Future<Result<Set<int>, Failure>> getWatched(int animeId) => makeApiCall(
    () => mapAnistarErrors(() async {
      if (animeId <= 0) {
        throw const RequestFailure(message: 'Некорректный номер аниме.');
      }
      final account = _requireAccount();
      final watched = await _client.watchedEpisodes(animeId);
      if (_account() != account) {
        throw const RequestFailure(message: 'Аккаунт изменился.');
      }
      if (watched.any((number) => number <= 0)) {
        throw const RequestFailure(message: 'Некорректные номера серий.');
      }

      return Set.unmodifiable(watched);
    }),
  );

  @override
  Future<Result<Set<int>, Failure>> markStarted({required int animeId, required int episodeNumber}) => makeApiCall(
    () => mapAnistarErrors(() async {
      if (animeId <= 0 || episodeNumber <= 0) {
        throw const RequestFailure(message: 'Некорректный номер аниме или серии.');
      }
      final account = _requireAccount();
      final watched = await _client.markWatched(animeId: animeId, episodeNumber: episodeNumber);
      if (_account() != account) {
        throw const RequestFailure(message: 'Аккаунт изменился.');
      }
      if (watched.any((number) => number <= 0) || !watched.contains(episodeNumber)) {
        throw const RequestFailure(message: 'AniStar не подтвердил отметку просмотра.');
      }

      return Set.unmodifiable(watched);
    }),
  );

  String _requireAccount() {
    final account = _account();
    if (account == null) {
      throw const RequestFailure(message: 'Войдите в аккаунт для истории просмотра.');
    }

    return account;
  }
}
