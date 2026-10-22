// Pumps and focus reads observe successive remote events.
// ignore_for_file: prefer-moving-to-variable

import 'package:anistar_tv/packages/features/player/domain/models/playback_quality.dart';
import 'package:anistar_tv/packages/features/player/domain/models/playback_session.dart';
import 'package:anistar_tv/packages/features/player/presentation/widgets/player_overlay.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:video_player/video_player.dart';

import '../../../../../support/test_app.dart';

void main() {
  testWidgets('fits compact TV layout and exposes playback controls', (tester) async {
    Duration? seekPosition;
    var playPauseCalls = 0;

    await pumpTvApp(
      tester,
      Scaffold(
        backgroundColor: Colors.black,
        body: PlayerOverlay(
          title: 'Тестовое аниме с достаточно длинным названием',
          episodeNumber: 2,
          session: PlaybackSession(
            manifestUri: Uri.parse('https://parser.test/manifest.m3u8'),
            requestedQuality: PlaybackQuality.high,
            selectedQuality: PlaybackQuality.high,
            availableQualities: const [PlaybackQuality.high],
          ),
          value: const VideoPlayerValue(
            duration: Duration(minutes: 24),
            position: Duration(minutes: 10),
            isInitialized: true,
            isPlaying: true,
          ),
          onPlayPause: () => playPauseCalls++,
          onSeek: (position) => seekPosition = position,
        ),
      ),
      wrapInScaffold: false,
    );

    expect(tester.takeException(), isNull);
    expect(find.textContaining('Серия 2'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('player-forward')));
    expect(seekPosition, const Duration(minutes: 10, seconds: 10));
    await tester.tap(find.byKey(const ValueKey('player-play')));
    expect(playPauseCalls, 1);
  });
  testWidgets('remote timeline clamps seeks and returns focus to the selected control', (tester) async {
    final play = FocusNode();
    addTearDown(play.dispose);
    final seeks = <Duration>[];
    var qualityCalls = 0;
    await pumpTvApp(
      tester,
      PlayerOverlay(
        title: 'Аниме',
        episodeNumber: 1,
        session: _session,
        value: const VideoPlayerValue(
          duration: Duration(seconds: 24),
          position: Duration(seconds: 20),
          isInitialized: true,
        ),
        playFocusNode: play,
        onPlayPause: () => fail('Unexpected activation'),
        onSeek: seeks.add,
        onSelectQuality: () => qualityCalls++,
      ),
    );
    play.requestFocus();
    await tester.pump();
    // Disabled episode action is omitted from both layout and remote navigation.
    for (var i = 0; i < 3; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
    }
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pump();
    expect(qualityCalls, 1);
    expect(seeks, isEmpty);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'Позиция видео');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    expect(seeks.last, const Duration(seconds: 24));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    expect(seeks.last, const Duration(seconds: 10));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'Качество');
    expect(find.byIcon(Icons.fullscreen), findsNothing);
    expect(find.textContaining('OK'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('rewind clamps at zero and touch timeline seeks', (tester) async {
    Duration? target;
    await pumpTvApp(
      tester,
      PlayerOverlay(
        title: 'Аниме',
        episodeNumber: 1,
        session: _session,
        value: const VideoPlayerValue(
          duration: Duration(seconds: 24),
          position: Duration(seconds: 2),
          isInitialized: true,
        ),
        onPlayPause: () => fail('Unexpected activation'),
        onSeek: (position) => target = position,
      ),
    );
    await tester.tap(find.byKey(const ValueKey('player-rewind')));
    expect(target, Duration.zero);
    await tester.tapAt(tester.getCenter(find.byType(Slider)));
    expect(target?.inSeconds, closeTo(12, 1));
  });

  for (final (name, size) in [('compact', compactTvSize), ('wide', wideTvSize)]) {
    testWidgets('player controls and timeline at $name viewport', (tester) async {
      final play = FocusNode();
      addTearDown(play.dispose);
      await pumpTvApp(
        tester,
        Scaffold(
          backgroundColor: Colors.black,
          body: PlayerOverlay(
            title: 'Тестовое аниме с длинным названием',
            episodeNumber: 2,
            session: _session,
            value: VideoPlayerValue(
              duration: const Duration(minutes: 24),
              position: const Duration(minutes: 10),
              buffered: [DurationRange(Duration.zero, const Duration(minutes: 16))],
              isInitialized: true,
              isPlaying: true,
            ),
            playFocusNode: play,
            onPlayPause: () => fail('Unexpected activation'),
            onSeek: (_) => fail('Unexpected seek'),
            onBack: () => fail('Unexpected activation'),
            onSelectEpisode: () => fail('Unexpected activation'),
            onPreviousEpisode: () => fail('Unexpected activation'),
            onNextEpisode: () => fail('Unexpected activation'),
            onSelectQuality: () => fail('Unexpected activation'),
          ),
        ),
        size: size,
        wrapInScaffold: false,
      );
      play.requestFocus();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        tester.getRect(find.byType(Slider)).bottom,
        lessThanOrEqualTo(tester.getRect(find.byKey(const ValueKey('player-play'))).top),
      );
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/player_$name.png'));
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/player_timeline_$name.png'));
    }, tags: ['golden']);
  }
}

final _session = PlaybackSession(
  manifestUri: Uri.parse('https://parser.test/manifest.m3u8'),
  requestedQuality: PlaybackQuality.high,
  selectedQuality: PlaybackQuality.high,
  availableQualities: const [PlaybackQuality.low, PlaybackQuality.high],
);
