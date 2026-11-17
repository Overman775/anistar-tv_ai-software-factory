// Pumps and focus reads observe successive remote events.

import 'package:anistar_tv/packages/features/player/domain/models/playback_episode.dart';
import 'package:anistar_tv/packages/features/player/domain/models/playback_quality.dart';
import 'package:anistar_tv/packages/features/player/domain/models/playback_session.dart';
import 'package:anistar_tv/packages/features/player/presentation/widgets/player_overlay.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:video_player/video_player.dart';

import '../../../../../support/decoded_fixture_image.dart';
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
            episodes: const [],
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

  testWidgets('timeline accepts seeks at both vertical edges before and after focus', (tester) async {
    final seeks = <Duration>[];
    final play = FocusNode();
    addTearDown(play.dispose);
    await pumpTvApp(
      tester,
      PlayerOverlay(
        title: 'Аниме',
        episodeNumber: 1,
        session: _session,
        value: const VideoPlayerValue(duration: Duration(seconds: 100), isInitialized: true),
        playFocusNode: play,
        onPlayPause: () => fail('Unexpected activation'),
        onSeek: seeks.add,
      ),
    );
    play.requestFocus();
    await tester.pumpAndSettle();
    final slider = find.byType(Slider);
    for (final focused in [false, true]) {
      if (focused) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await tester.pumpAndSettle();
        expect(FocusManager.instance.primaryFocus?.debugLabel, 'Позиция видео');
      }
      final rect = tester.getRect(slider);
      expect(rect.height, greaterThanOrEqualTo(48));
      for (final y in [rect.top + 1, rect.bottom - 1]) {
        final before = seeks.length;
        await tester.tapAt(Offset(rect.center.dx, y));
        await tester.pump();
        expect(seeks.length, greaterThan(before));
        expect(seeks.last.inSeconds, closeTo(50, 2));
      }
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('640x360 keeps the full timer, actions and remote path available', (tester) async {
    final play = FocusNode(debugLabel: 'Пауза / воспроизведение');
    addTearDown(play.dispose);
    await pumpTvApp(
      tester,
      Scaffold(
        backgroundColor: Colors.black,
        body: PlayerOverlay(
          title: 'Длинное название аниме для компактного телевизионного экрана',
          episodeNumber: 12,
          session: PlaybackSession(
            manifestUri: Uri.parse('https://parser.test/manifest.m3u8'),
            requestedQuality: PlaybackQuality.high,
            selectedQuality: PlaybackQuality.high,
            availableQualities: const [PlaybackQuality.low, PlaybackQuality.high],
            episodes: List.generate(
              24,
              (index) => PlaybackEpisode(number: index + 1, title: 'Серия ${index + 1}', isWatched: index < 11),
            ),
          ),
          value: VideoPlayerValue(
            duration: const Duration(hours: 1, minutes: 24, seconds: 35),
            position: const Duration(hours: 1, minutes: 5, seconds: 12),
            buffered: [DurationRange(Duration.zero, const Duration(hours: 1, minutes: 16))],
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
      size: const Size(640, 360),
      textScale: 1,
      disableAnimations: true,
      wrapInScaffold: false,
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final timer = find.text('1:05:12 / 1:24:35');
    expect(timer, findsOneWidget);
    final timerParagraph = tester.renderObject<RenderParagraph>(timer);
    expect(timerParagraph.didExceedMaxLines, isFalse);
    expect(tester.getRect(timer).right, lessThanOrEqualTo(640));
    for (final key in [
      'player-play',
      'player-rewind',
      'player-forward',
      'player-previous-episode',
      'player-next-episode',
      'player-episodes',
      'player-quality',
    ]) {
      final button = find.byKey(ValueKey(key));
      expect(button, findsOneWidget);
      expect(tester.getRect(button).right, lessThanOrEqualTo(640));
      expect(tester.getRect(button).height, greaterThanOrEqualTo(48));
    }
    play.requestFocus();
    await tester.pumpAndSettle();
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'Пауза / воспроизведение');
    final labels = <String?>[FocusManager.instance.primaryFocus?.debugLabel];
    for (var index = 0; index < 6; index++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      labels.add(FocusManager.instance.primaryFocus?.debugLabel);
    }
    expect(labels, [
      'Пауза / воспроизведение',
      'Назад на 10 секунд',
      'Вперёд на 10 секунд',
      'Предыдущая серия',
      'Следующая серия',
      'Серии',
      'Качество',
    ]);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'Позиция видео');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'Качество');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('player controls and timeline at tv profile', (tester) async {
    final frame = await cacheDecodedFixtureImage(tester, filePath: 'prototype/assets/frieren.jpg');
    final play = FocusNode();
    addTearDown(play.dispose);
    await pumpScreenGolden(
      tester,
      Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            RawImage(image: frame, fit: BoxFit.cover),
            PlayerOverlay(
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
          ],
        ),
      ),
      wrapInScaffold: false,
    );
    play.requestFocus();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(
      tester.getRect(find.byType(Slider)).bottom,
      lessThanOrEqualTo(tester.getRect(find.byKey(const ValueKey('player-play'))).top),
    );
    SliderThemeData sliderTheme() => tester
        .widget<SliderTheme>(find.ancestor(of: find.byType(Slider), matching: find.byType(SliderTheme)).first)
        .data;
    expect(sliderTheme().trackHeight, closeTo(2.268, 0.01));
    final thumbShape = sliderTheme().thumbShape;
    final overlayShape = sliderTheme().overlayShape;
    if (thumbShape is! RoundSliderThumbShape || overlayShape is! RoundSliderOverlayShape) {
      throw TestFailure('The player timeline must use the rounded thumb and overlay shapes');
    }
    expect(thumbShape.enabledThumbRadius, closeTo(4, 0.01));
    expect(overlayShape.overlayRadius, closeTo(12.042, 0.01));
    await expectScreenGolden('player');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();
    expect(sliderTheme().trackHeight, closeTo(4.536, 0.01));
    final focusedThumb = sliderTheme().thumbShape;
    if (focusedThumb is! RoundSliderThumbShape) {
      throw TestFailure('The focused player timeline must use the rounded thumb shape');
    }
    expect(focusedThumb.enabledThumbRadius, closeTo(7, 0.01));
    await expectScreenGolden('player_timeline');
  }, tags: ['golden']);
}

final _session = PlaybackSession(
  manifestUri: Uri.parse('https://parser.test/manifest.m3u8'),
  requestedQuality: PlaybackQuality.high,
  selectedQuality: PlaybackQuality.high,
  availableQualities: const [PlaybackQuality.low, PlaybackQuality.high],
  episodes: const [],
);
