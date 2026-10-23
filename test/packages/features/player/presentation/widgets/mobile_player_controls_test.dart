// Golden matrix and callback observations intentionally reuse fixture state.
import 'package:anistar_tv/packages/features/player/domain/models/playback_quality.dart';
import 'package:anistar_tv/packages/features/player/domain/models/playback_session.dart';
import 'package:anistar_tv/packages/features/player/presentation/widgets/mobile_player_controls.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:video_player/video_player.dart';

import '../../../../../support/test_app.dart';

final _session = PlaybackSession(
  manifestUri: Uri.parse('https://fixture.test/manifest.m3u8'),
  requestedQuality: PlaybackQuality.high,
  selectedQuality: PlaybackQuality.high,
  availableQualities: PlaybackQuality.values,
);

void main() {
  testWidgets('touch controls expose transport, choices, back and rotation and clamp seek', (tester) async {
    final calls = <String>[];
    final seeks = <Duration>[];
    await pumpMobileApp(
      tester,
      MobilePlayerControls(
        title: 'Аниме',
        episodeNumber: 2,
        session: _session,
        value: const VideoPlayerValue(duration: Duration(seconds: 24), position: Duration(seconds: 2), isPlaying: true),
        onPlayPause: () => calls.add('pause'),
        onSeek: seeks.add,
        onSelectEpisode: () => calls.add('episodes'),
        onSelectQuality: () => calls.add('quality'),
        onPreviousEpisode: () => calls.add('previous'),
        onNextEpisode: () => calls.add('next'),
        onRotate: () => calls.add('rotate'),
        onBack: () => calls.add('back'),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('player-rewind')));
    expect(seeks.last, Duration.zero);
    await tester.tap(find.byKey(const ValueKey('player-forward')));
    expect(seeks.last, const Duration(seconds: 12));
    for (final key in ['play', 'episodes', 'quality', 'previous-episode', 'next-episode', 'rotate', 'back']) {
      final finder = find.byKey(ValueKey('player-$key'));
      final rect = tester.getRect(finder);
      expect(rect.width, greaterThanOrEqualTo(48));
      expect(rect.height, greaterThanOrEqualTo(48));
      await tester.tap(finder);
    }
    expect(calls, ['pause', 'episodes', 'quality', 'previous', 'next', 'rotate', 'back']);
    await tester.tapAt(tester.getCenter(find.byType(Slider)));
    expect(seeks.last.inSeconds, closeTo(12, 1));
    expect(tester.takeException(), isNull);
  });

  for (final (name, size, scale) in [
    ('small', const Size(320, 568), 1.0),
    ('portrait', const Size(390, 844), 1.0),
    ('portrait_scaled', const Size(320, 568), 2.0),
    ('landscape_scaled', const Size(640, 320), 2.0),
  ]) {
    testWidgets('mobile player $name fits and keeps all actions visible', (tester) async {
      final calls = <String>[];
      final seeks = <Duration>[];
      await pumpMobileApp(
        tester,
        Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
            child: MobilePlayerControls(
              title: 'Очень длинное название сериала для проверки доступности управления',
              episodeNumber: 24,
              session: _session,
              value: const VideoPlayerValue(
                duration: Duration(minutes: 24),
                position: Duration(minutes: 10),
                isPlaying: true,
              ),
              onPlayPause: () => calls.add('pause'),
              onSeek: seeks.add,
              onSelectEpisode: () => calls.add('episodes'),
              onSelectQuality: () => calls.add('quality'),
              onPreviousEpisode: () => calls.add('previous'),
              onNextEpisode: () => calls.add('next'),
              onRotate: () => calls.add('rotate'),
              onBack: () => calls.add('back'),
            ),
          ),
        ),
        size: size,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final play = tester.getRect(find.byKey(const ValueKey('player-play')));
      final back = tester.getRect(find.byKey(const ValueKey('player-back')));
      final timeline = tester.getRect(find.byKey(const ValueKey('player-timeline')));
      expect(play.top, greaterThanOrEqualTo(back.bottom));
      expect(play.bottom, lessThanOrEqualTo(timeline.top));
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/mobile_player_$name.png'));
      for (final key in ['play', 'episodes', 'quality', 'previous-episode', 'next-episode', 'rotate', 'back']) {
        await tester.tap(find.byKey(ValueKey('player-$key')));
      }
      expect(calls, ['pause', 'episodes', 'quality', 'previous', 'next', 'rotate', 'back']);
      await tester.tapAt(timeline.center);
      expect(seeks, isNotEmpty);
      expect(seeks.last.inSeconds, closeTo(12 * 60, 1));
    }, tags: ['golden']);
  }
}
