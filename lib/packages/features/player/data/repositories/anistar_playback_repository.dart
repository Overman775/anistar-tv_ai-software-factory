import 'package:anistar/anistar.dart';
import 'package:core/data.dart';
import 'package:networking/networking.dart';

import '../../domain/models/playback_quality.dart';
import '../../domain/models/playback_session.dart';
import '../../domain/repositories/playback_repository.dart';

final class AnistarPlaybackRepository extends BaseRepository implements PlaybackRepository {
  final AnistarSource _source;

  AnistarPlaybackRepository(this._source, [super.logger]);

  @override
  Future<Result<PlaybackSession, Failure>> createSession({
    required int animeId,
    required int episodeNumber,
    PlaybackQuality quality = PlaybackQuality.high,
  }) => makeApiCall(() async {
    final episodes = await _source.episodes(animeId);
    final matches = episodes.where((episode) => episode.number == episodeNumber);
    if (matches.isEmpty) {
      throw const AnistarFailure(message: 'Эта серия пока недоступна.');
    }
    final sources = matches.first.sources;
    final available = PlaybackQuality.values
        .where((value) => sources.containsKey(value.apiValue))
        .toList(growable: false);
    if (available.isEmpty) {
      throw const AnistarFailure(message: 'Для этой серии не найден HLS-поток.');
    }
    final selected = available.contains(quality) ? quality : available.last;
    final uri = sources[selected.apiValue]!;
    final end = RegExp(r'end=(\d+)').firstMatch(uri.toString());
    final expiresSeconds = int.tryParse(end?.group(1) ?? '');

    return PlaybackSession(
      manifestUri: uri,
      requestedQuality: quality,
      selectedQuality: selected,
      availableQualities: available,
      episodeNumbers: episodes.map((episode) => episode.number).toList(growable: false),
      watchedEpisodes: episodes.where((episode) => episode.isWatched).map((episode) => episode.number).toSet(),
      httpHeaders: {'Referer': _source.playerUri(animeId).toString()},
      // Expiry is optional metadata. An unsupported timestamp must not prevent
      // playback of an otherwise intact signed URL.
      expiresAt: expiresSeconds == null || expiresSeconds > 8640000000000
          ? null
          : DateTime.fromMillisecondsSinceEpoch(expiresSeconds * 1000, isUtc: true),
    );
  });
}
