import 'package:anistar/anistar.dart';
import 'package:core/data.dart';
import 'package:networking/networking.dart';

import '../../../common/data/anistar_errors.dart';
import '../../domain/models/playback_failure.dart';
import '../../domain/models/playback_quality.dart';
import '../../domain/models/playback_session.dart';
import '../../domain/repositories/playback_repository.dart';

final class AnistarPlaybackRepository extends BaseRepository implements PlaybackRepository {
  final AnistarClient _client;
  final bool Function() _canUseAccount;

  AnistarPlaybackRepository(this._client, [super.logger, bool Function()? canUseAccount])
    : _canUseAccount = canUseAccount ?? (() => false);

  @override
  Future<Result<PlaybackSession, Failure>> createSession({
    required int animeId,
    required int episodeNumber,
    PlaybackQuality quality = PlaybackQuality.high,
  }) => makeApiCall(
    () => mapAnistarErrors(() async {
      if (animeId <= 0 || episodeNumber <= 0) {
        throw const PlaybackFailure(message: 'Некорректный номер аниме или серии.');
      }
      final episodes = await _client.episodes(animeId);
      final numbers = <int>{};
      if (episodes.any((item) => item.number <= 0 || !numbers.add(item.number))) {
        throw const PlaybackFailure(message: 'Некорректные номера серий.');
      }
      final matches = episodes.where((episode) => episode.number == episodeNumber);
      if (matches.isEmpty) {
        throw const PlaybackFailure(message: 'Эта серия пока недоступна.');
      }
      final sources = matches.first.sources;
      final available = PlaybackQuality.values
          .where((value) => sources.any((source) => source.height == value.height))
          .toList(growable: false);
      if (available.isEmpty) {
        throw const PlaybackFailure(message: 'Для этой серии не найден HLS-поток.');
      }
      final selected = available.contains(quality) ? quality : available.last;
      final source = sources.firstWhere((source) => source.height == selected.height);

      return PlaybackSession(
        manifestUri: source.manifestUri,
        requestedQuality: quality,
        selectedQuality: selected,
        availableQualities: available,
        episodeNumbers: numbers.toList()..sort(),
        watchedEpisodes: _canUseAccount()
            ? episodes.where((episode) => episode.isWatched).map((episode) => episode.number).toSet()
            : const {},
        httpHeaders: source.httpHeaders,
        expiresAt: source.expiresAt,
      );
    }),
  );
}
