import 'dart:async';

import 'package:anistar_tv/packages/features/player/domain/models/playback_quality.dart';
import 'package:anistar_tv/packages/features/player/domain/models/playback_session.dart';
import 'package:anistar_tv/packages/features/player/player_providers.dart';
import 'package:anistar_tv/packages/features/player/presentation/screens/player_screen.dart';
import 'package:anistar_tv/packages/features/player/presentation/widgets/player_view.dart';
import 'package:anistar_tv/packages/features/watch_history/watched_episodes.dart';
import 'package:anistar_tv/packages/features/watch_history/watched_episodes_repository.dart';
import 'package:core/data.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:video_player/video_player.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart' as platform;

import '../../../../../mocks/features/fake_watched_episodes_repository.dart';
import '../../../../../mocks/features/player/fake_playback_repository.dart';
import '../../../../../mocks/features/player/fake_video_platform.dart';
import '../../../../../support/test_app.dart';

// Each await advances the player lifecycle. Repeating pumps and reading mutable
// fake state again is intentional; caching those results changes the test.
// ignore_for_file: prefer-moving-to-variable

void main() {
  late FakeVideoPlatform video;
  late platform.VideoPlayerPlatform previousPlatform;
  late FakePlaybackRepository repository;

  setUp(() {
    previousPlatform = platform.VideoPlayerPlatform.instance;
    video = FakeVideoPlatform();
    repository = FakePlaybackRepository();
    platform.VideoPlayerPlatform.instance = video;
  });

  tearDown(() => platform.VideoPlayerPlatform.instance = previousPlatform);

  Future<void> settle(WidgetTester tester) async {
    // Stream cancellation may complete on the real event loop, as native plugin
    // channels do. Flush both loops before waiting for Flutter animations.
    for (var i = 0; i < 8; i++) {
      await tester.pump();
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    }
    await tester.pumpAndSettle();
  }

  Future<void> mount(WidgetTester tester) async {
    await pumpTvApp(
      tester,
      const PlayerScreen(animeId: 10938, episodeNumber: 1, title: 'Аниме'),
      overrides: [playbackRepositoryProvider.overrideWithValue(repository)],
      wrapInScaffold: false,
    );
    await settle(tester);
  }

  Future<void> openMenu(WidgetTester tester, {bool episodes = false}) async {
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await settle(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    for (var i = 0; i < (episodes ? 3 : 4); i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
    }
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await settle(tester);
    expect(find.text(episodes ? 'Выбор серии' : 'Качество видео'), findsOneWidget);
  }

  testWidgets('dedicated media Play and Pause keys do not toggle their requested state', (tester) async {
    await mount(tester);
    final controller = tester.widget<VideoPlayer>(find.byType(VideoPlayer)).controller;
    final states = <bool>[];
    for (final key in [
      LogicalKeyboardKey.mediaPlay,
      LogicalKeyboardKey.mediaPause,
      LogicalKeyboardKey.mediaPause,
      LogicalKeyboardKey.mediaPlay,
    ]) {
      await tester.sendKeyEvent(key);
      await settle(tester);
      states.add(controller.value.isPlaying);
    }
    expect(states, [true, false, false, true]);
    expect(video.sources, hasLength(1));
    await tester.pumpWidget(const SizedBox());
    await settle(tester);
  });

  testWidgets('hidden controls reveal focus, remain visible and never seek while navigating buttons', (tester) async {
    await mount(tester);
    final controller = tester.widget<VideoPlayer>(find.byType(VideoPlayer)).controller;
    await tester.pump(const Duration(seconds: 5));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    await tester.pump();
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'К сериям');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'Позиция видео');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'Пауза / воспроизведение');
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await settle(tester);
    expect(controller.value.isPlaying, isFalse);
    await tester.sendKeyEvent(LogicalKeyboardKey.mediaPlay);
    await settle(tester);
    await tester.pump(const Duration(seconds: 5));
    expect(tester.widget<PlayerView>(find.byType(PlayerView)).controlsVisible, isTrue);
    expect(controller.value.position, Duration.zero);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'Видео');
    await tester.pump(const Duration(seconds: 5));
    expect(tester.widget<PlayerView>(find.byType(PlayerView)).controlsVisible, isFalse);
    await tester.pumpWidget(const SizedBox());
    await settle(tester);
  });

  testWidgets('Up and OK leave the player through the visible back button and dispose native video', (tester) async {
    await pumpTvApp(
      tester,
      const Text('Список серий'),
      overrides: [playbackRepositoryProvider.overrideWithValue(repository)],
    );
    unawaited(
      Navigator.of(tester.element(find.text('Список серий'))).push(
        MaterialPageRoute<void>(builder: (_) => const PlayerScreen(animeId: 10938, episodeNumber: 1, title: 'Аниме')),
      ),
    );
    await settle(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    await tester.pump();
    expect(find.byTooltip('К сериям'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await settle(tester);
    expect(find.byType(PlayerScreen), findsNothing);
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
    expect(video.disposed, [1]);
  });

  testWidgets('native pause reveals hidden controls; native resume restores their hide timer', (tester) async {
    await mount(tester);
    final controller = tester.widget<VideoPlayer>(find.byType(VideoPlayer)).controller;
    await tester.pump(const Duration(seconds: 5));
    expect(tester.widget<PlayerView>(find.byType(PlayerView)).controlsVisible, isFalse);
    await controller.pause();
    await settle(tester);
    await tester.pump(const Duration(seconds: 5));
    expect(tester.widget<PlayerView>(find.byType(PlayerView)).controlsVisible, isTrue);
    expect(controller.value.isPlaying, isFalse);
    await controller.play();
    await tester.pump(const Duration(seconds: 5));
    // Check hiding again after a separate native resume transition.
    expect(tester.widget<PlayerView>(find.byType(PlayerView)).controlsVisible, isFalse);
    await tester.pumpWidget(const SizedBox());
    await settle(tester);
  });

  testWidgets('completion reveals controls without fetching another source', (tester) async {
    await mount(tester);
    await tester.pump(const Duration(seconds: 5));
    video.events[1]?.add(platform.VideoEvent(eventType: platform.VideoEventType.completed));
    await settle(tester);
    final controller = tester.widget<VideoPlayer>(find.byType(VideoPlayer)).controller;
    expect(controller.value.isCompleted, isTrue);
    expect(controller.value.isPlaying, isFalse);
    expect(tester.widget<PlayerView>(find.byType(PlayerView)).controlsVisible, isTrue);
    expect(repository.calls, 1);
    await tester.pumpWidget(const SizedBox());
    await settle(tester);
  });

  testWidgets('marks after native play, not during initialization; quality changes do not duplicate writes', (
    tester,
  ) async {
    final storage = FakeWatchedEpisodesRepository();
    final native = video..delayInitialization = true;
    final overrides = [
      playbackRepositoryProvider.overrideWithValue(repository),
      watchedEpisodesRepositoryProvider.overrideWithValue(storage),
      watchHistoryAccountProvider.overrideWithValue('tester'),
    ];
    await pumpTvApp(
      tester,
      const PlayerScreen(animeId: 10938, episodeNumber: 1, title: 'Аниме'),
      overrides: overrides,
      wrapInScaffold: false,
    );
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    expect(storage.writes, 0);
    native.delayInitialization = false;
    native.events[1]!.add(
      platform.VideoEvent(
        eventType: platform.VideoEventType.initialized,
        duration: const Duration(minutes: 24),
        size: const Size(1280, 720),
      ),
    );
    await settle(tester);
    expect(storage.watched[10938], {1});
    await openMenu(tester);
    await tester.tap(find.text('360p'));
    await settle(tester);
    expect(storage.writes, 1);
    await openMenu(tester, episodes: true);
    expect(find.text('Серия 1 — просмотрена ✓'), findsOneWidget);
    await tester.tap(find.text('Серия 2'));
    await settle(tester);
    expect(storage.watched[10938], {1, 2});
    await tester.pumpWidget(const SizedBox());
    await settle(tester);
  });

  testWidgets('failed native initialization never persists a watched mark', (tester) async {
    final storage = FakeWatchedEpisodesRepository();
    video.failInitialization = true;
    await pumpTvApp(
      tester,
      const PlayerScreen(animeId: 10938, episodeNumber: 1, title: 'Аниме'),
      overrides: [
        playbackRepositoryProvider.overrideWithValue(repository),
        watchedEpisodesRepositoryProvider.overrideWithValue(storage),
        watchHistoryAccountProvider.overrideWithValue('tester'),
      ],
      wrapInScaffold: false,
    );
    await settle(tester);
    expect(storage.writes, 0);
    expect(find.text('Видео не запустилось'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await settle(tester);
  });

  testWidgets('history write failure shows a message while playback continues without repeated writes', (tester) async {
    final storage = FakeWatchedEpisodesRepository()..failWrite = true;
    await pumpTvApp(
      tester,
      const PlayerScreen(animeId: 10938, episodeNumber: 1, title: 'Аниме'),
      overrides: [
        playbackRepositoryProvider.overrideWithValue(repository),
        watchedEpisodesRepositoryProvider.overrideWithValue(storage),
        watchHistoryAccountProvider.overrideWithValue('tester'),
      ],
      wrapInScaffold: false,
    );
    await settle(tester);
    expect(find.text('Не удалось сохранить отметку просмотра.'), findsOneWidget);
    final controller = tester.widget<VideoPlayer>(find.byType(VideoPlayer)).controller;
    expect(controller.value.isPlaying, isTrue);
    await controller.seekTo(const Duration(seconds: 10));
    await settle(tester);
    expect(storage.writes, 1);
    await tester.pumpWidget(const SizedBox());
    await settle(tester);
  });

  testWidgets('updating the route replaces the source and resets the position', (tester) async {
    final native = video;
    final repo = repository;
    await mount(tester);
    final controller = tester.widget<VideoPlayer>(find.byType(VideoPlayer)).controller;
    await controller.seekTo(const Duration(seconds: 120));
    await pumpTvApp(
      tester,
      const PlayerScreen(animeId: 10939, episodeNumber: 2, title: 'Другое аниме'),
      overrides: [playbackRepositoryProvider.overrideWithValue(repo)],
      wrapInScaffold: false,
    );
    await settle(tester);
    expect(repo.anime, 10939);
    expect(repo.episode, 2);
    expect(native.disposed, [1]);
    expect(tester.widget<VideoPlayer>(find.byType(VideoPlayer)).controller.value.position, Duration.zero);
    await tester.pumpWidget(const SizedBox());
    await settle(tester);
  });

  testWidgets('a native seek exception recovers once without escaping the UI callback', (tester) async {
    final native = video;
    final repo = repository;
    await mount(tester);
    native.failNextSeek = true;
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await settle(tester);
    expect(repo.calls, 2);
    expect(native.disposed, [1]);
    expect(find.byType(VideoPlayer), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await settle(tester);
  });

  testWidgets('Back cancels a chooser and returns remote play and seek to the same native stream', (tester) async {
    await mount(tester);
    final native = video;
    final controller = tester.widget<VideoPlayer>(find.byType(VideoPlayer)).controller;
    await controller.pause();
    await openMenu(tester);
    await tester.binding.handlePopRoute();
    await settle(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await settle(tester);
    expect(controller.value.isPlaying, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await settle(tester);
    expect(controller.value.position, const Duration(seconds: 10));
    expect(native.sources, hasLength(1));
    expect(native.disposed, isEmpty);
    await tester.pumpWidget(const SizedBox());
    await settle(tester);
  });

  testWidgets('OK retries a failed stream without searching for the retry button', (tester) async {
    video.failInitialization = true;
    await mount(tester);
    expect(find.text('Видео не запустилось'), findsOneWidget);
    video.failInitialization = false;
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await settle(tester);
    expect(find.byType(VideoPlayer), findsOneWidget);
    expect(tester.widget<VideoPlayer>(find.byType(VideoPlayer)).controller.value.isPlaying, isTrue);
    await tester.pumpWidget(const SizedBox());
    await settle(tester);
  });

  testWidgets('leaving during native initialization disposes the unfinished controller', (tester) async {
    final native = video..delayInitialization = true;
    await pumpTvApp(
      tester,
      const PlayerScreen(animeId: 10938, episodeNumber: 1, title: 'Аниме'),
      overrides: [playbackRepositoryProvider.overrideWithValue(repository)],
      wrapInScaffold: false,
    );
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    expect(native.sources, hasLength(1));
    await tester.pumpWidget(const SizedBox());
    // The native plugin doesn't complete initialize after disposal. Its timeout
    // must discard the obsolete attempt without retrying or creating a player.
    await tester.pump(const Duration(seconds: 36));
    await settle(tester);
    expect(native.disposed, [1]);
    expect(native.sources, hasLength(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('native source receives HLS and Referer; runtime error refreshes once and restores position', (
    tester,
  ) async {
    final native = video;
    final repo = repository;
    await mount(tester);
    expect(native.sources.single.httpHeaders['Referer'], contains('id=10938'));
    expect(native.sources.single.formatHint, platform.VideoFormat.hls);
    final controller = tester.widget<VideoPlayer>(find.byType(VideoPlayer)).controller;
    await controller.seekTo(const Duration(seconds: 120));
    native.events[1]?.addError(PlatformException(code: 'VideoError', message: 'Expired URL'));
    await tester.pump(const Duration(milliseconds: 100));
    await settle(tester);
    expect(repo.calls, 2);
    expect(native.sources.last.uri, isNot(native.sources.first.uri));
    expect(native.seeks.last, const Duration(seconds: 120));
    expect(native.disposed, [1]);
    final replacement = tester.widget<VideoPlayer>(find.byType(VideoPlayer)).controller;
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await settle(tester);
    expect(replacement.value.isPlaying, isFalse);
    native.events[2]?.addError(PlatformException(code: 'VideoError', message: 'Persistent source error'));
    await settle(tester);
    expect(native.sources, hasLength(2));
    expect(find.text('Воспроизведение прервано'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await settle(tester);
    expect(repo.calls, 3);
    final retried = tester.widget<VideoPlayer>(find.byType(VideoPlayer)).controller;
    expect(retried.value.isPlaying, isFalse);
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await settle(tester);
    expect(retried.value.isPlaying, isTrue);
    await tester.pumpWidget(const SizedBox());
    await settle(tester);
    expect(native.disposed, [1, 2, 3]);
  });

  testWidgets('persistent initialization failure has two attempts and a manual retry', (tester) async {
    final native = video;
    final repo = repository;
    native.failInitialization = true;
    await mount(tester);
    expect(repo.calls, 2);
    expect(find.text('Видео не запустилось'), findsOneWidget);
    expect(native.disposed, [1, 2]);
    native.failInitialization = false;
    await tester.tap(find.text('Повторить'));
    await settle(tester);
    expect(repo.calls, 3);
    expect(find.byType(VideoPlayer), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await settle(tester);
  });

  testWidgets('source recovery preserves a paused player instead of autoplaying', (tester) async {
    final native = video;
    await mount(tester);
    final controller = tester.widget<VideoPlayer>(find.byType(VideoPlayer)).controller;
    await controller.seekTo(const Duration(seconds: 120));
    await controller.pause();
    native.events[1]?.addError(PlatformException(code: 'VideoError', message: 'Expired URL'));
    await settle(tester);
    final replacement = tester.widget<VideoPlayer>(find.byType(VideoPlayer)).controller;
    expect(replacement.value.position, const Duration(seconds: 120));
    expect(replacement.value.isPlaying, isFalse);
    expect(native.disposed, [1]);
    await tester.pumpWidget(const SizedBox());
    await settle(tester);
  });

  testWidgets('TV keys select quality and episode; quality keeps position and episode resets it', (tester) async {
    final native = video;
    final repo = repository;
    await mount(tester);
    final controller = tester.widget<VideoPlayer>(find.byType(VideoPlayer)).controller;
    await controller.seekTo(const Duration(seconds: 120));
    await openMenu(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await settle(tester);
    expect(repo.quality, PlaybackQuality.low);
    expect(native.seeks.last, const Duration(seconds: 120));
    await openMenu(tester, episodes: true);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await settle(tester);
    expect(repo.episode, 2);
    expect(native.positions[3] ?? Duration.zero, Duration.zero);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await settle(tester);
  });

  testWidgets('leaving during page fetch discards late result without creating a controller', (tester) async {
    final native = video;
    final repo = repository..pending = Completer<Result<PlaybackSession, Failure>>();
    await pumpTvApp(
      tester,
      const PlayerScreen(animeId: 10938, episodeNumber: 1, title: 'Аниме'),
      overrides: [playbackRepositoryProvider.overrideWithValue(repo)],
      wrapInScaffold: false,
    );
    await tester.pumpWidget(const SizedBox());
    repo.pending?.complete(Result.success(repo.session));
    await settle(tester);
    expect(native.sources, isEmpty);
    expect(tester.takeException(), isNull);
  });
}
