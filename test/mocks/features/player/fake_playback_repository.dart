import 'dart:async';

import 'package:anistar_tv/packages/features/player/domain/models/playback_episode.dart';
import 'package:anistar_tv/packages/features/player/domain/models/playback_quality.dart';
import 'package:anistar_tv/packages/features/player/domain/models/playback_session.dart';
import 'package:anistar_tv/packages/features/player/domain/repositories/playback_repository.dart';
import 'package:core/data.dart';

final class FakePlaybackRepository implements PlaybackRepository {
  List<int> episodeNumbers = const [1, 2];
  int calls = 0;
  int episode = 1;
  int anime = 10938;
  PlaybackQuality quality = PlaybackQuality.high;
  PlaybackQuality? selectedQuality;
  List<PlaybackQuality> availableQualities = PlaybackQuality.values;
  Completer<Result<PlaybackSession, Failure>>? pending;

  PlaybackSession get session => PlaybackSession(
    manifestUri: Uri.parse('https://cdn.test/$calls/720.mp4'),
    requestedQuality: quality,
    selectedQuality: selectedQuality ?? quality,
    availableQualities: availableQualities,
    episodes: episodeNumbers
        .map((number) => PlaybackEpisode(number: number, title: 'Episode $number'))
        .toList(growable: false),
    httpHeaders: const {'Referer': 'https://v30.astar.bz/player?id=10938'},
  );

  @override
  Future<Result<PlaybackSession, Failure>> createSession({
    required int animeId,
    required int episodeNumber,
    PlaybackQuality quality = PlaybackQuality.high,
  }) {
    calls++;
    anime = animeId;
    episode = episodeNumber;
    this.quality = quality;

    return pending?.future ?? Future.value(Result.success(session));
  }
}
