import 'package:anistar_tv/packages/features/player/domain/models/playback_episode.dart';
import 'package:anistar_tv/packages/features/player/domain/models/playback_quality.dart';
import 'package:anistar_tv/packages/features/player/domain/models/playback_session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  PlaybackSession session({List<PlaybackEpisode> episodes = const [], List<int> episodeNumbers = const []}) =>
      PlaybackSession(
        manifestUri: Uri.parse('https://cdn.test/master.m3u8'),
        requestedQuality: PlaybackQuality.high,
        selectedQuality: PlaybackQuality.high,
        availableQualities: const [PlaybackQuality.low, PlaybackQuality.high],
        episodes: episodes,
        episodeNumbers: episodeNumbers,
        watchedEpisodes: const {2},
      );

  test('episode metadata and watched numbers are immutable snapshots', () {
    final input = [
      PlaybackEpisode(number: 2, title: 'Начало', previewUri: Uri.parse('https://cdn.test/2.jpg'), isWatched: true),
    ];
    final value = session(episodes: input);
    input.clear();
    final episode = value.episodes.single;

    expect(value.episodes, hasLength(1));
    expect(episode.number, 2);
    expect(episode.title, 'Начало');
    expect(episode.previewUri, Uri.parse('https://cdn.test/2.jpg'));
    expect(episode.isWatched, isTrue);
    expect(value.episodeNumbers, [2]);
    expect(value.watchedEpisodes, {2});
    expect(() => value.episodes.add(const PlaybackEpisode(number: 3, title: 'Следующая')), throwsUnsupportedError);
  });

  test('legacy episode numbers remain available as metadata-free immutable episodes', () {
    final numbers = [1, 3];
    final value = session(episodeNumbers: numbers);
    numbers.clear();

    expect(value.episodeNumbers, [1, 3]);
    expect(value.episodes.map((episode) => episode.number), [1, 3]);
    expect(value.episodes.map((episode) => episode.title), ['', '']);
    expect(value.episodes.every((episode) => episode.previewUri == null && !episode.isWatched), isTrue);
    expect(value.watchedEpisodes, {2});
  });
}
