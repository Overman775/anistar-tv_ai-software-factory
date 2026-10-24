import 'package:anistar_tv/packages/features/player/domain/models/playback_episode.dart';
import 'package:anistar_tv/packages/features/player/domain/models/playback_quality.dart';
import 'package:anistar_tv/packages/features/player/domain/models/playback_session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  PlaybackSession session({List<PlaybackEpisode> episodes = const []}) => PlaybackSession(
    manifestUri: Uri.parse('https://cdn.test/master.m3u8'),
    requestedQuality: PlaybackQuality.high,
    selectedQuality: PlaybackQuality.high,
    availableQualities: const [PlaybackQuality.low, PlaybackQuality.high],
    episodes: episodes,
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

  test('episode numbers and watched state are derived from immutable metadata', () {
    final episodes = [
      const PlaybackEpisode(number: 1, title: 'Первая'),
      const PlaybackEpisode(number: 3, title: 'Третья', isWatched: true),
    ];
    final value = session(episodes: episodes);
    episodes.clear();

    expect(value.episodeNumbers, [1, 3]);
    expect(value.watchedEpisodes, {3});
    expect(value.previousEpisode(3), 1);
    expect(value.nextEpisode(1), 3);
  });
}
