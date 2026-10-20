import 'dart:async';

import 'package:anistar_tv/packages/features/player/domain/models/playback_quality.dart';
import 'package:anistar_tv/packages/features/player/domain/models/playback_session.dart';
import 'package:anistar_tv/packages/features/player/player_providers.dart';
import 'package:anistar_tv/packages/features/player/presentation/screens/player_screen.dart';
import 'package:anistar_tv/packages/features/player/presentation/widgets/player_view.dart';
import 'package:anistar_tv/packages/features/watch_history/watch_history_providers.dart';
import 'package:anistar_tv/packages/features/watch_history/watched_episodes.dart';
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
  final awakeCalls = <bool>[];
  const awakeChannel = MethodChannel('anistar_tv/playback_screen_awake');

  setUp(() {
    TestWidgetsFlutterBinding.instance.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    awakeCalls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(awakeChannel, (
      call,
    ) async {
      awakeCalls.add(call.arguments as bool);

      return null;
    });
    previousPlatform = platform.VideoPlayerPlatform.instance;
    video = FakeVideoPlatform();
    repository = FakePlaybackRepository();
    platform.VideoPlayerPlatform.instance = video;
  });

  tearDown(() {
    platform.VideoPlayerPlatform.instance = previousPlatform;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(awakeChannel, null);
  });

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
    for (var i = 0; i < 8 && FocusManager.instance.primaryFocus?.debugLabel != (episodes ? 'Серии' : 'Качество'); i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
    }
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await settle(tester);
    expect(find.text(episodes ? 'Выбор серии' : 'Качество видео'), findsOneWidget);
  }

  bool controlsVisible(WidgetTester tester) => tester.widget<PlayerView>(find.byType(PlayerView)).controlsVisible;

  double previewSeconds(WidgetTester tester) => tester.widget<Slider>(find.byType(Slider)).value / 1000;

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await settle(tester);
    expect(tester.takeException(), isNull);
  }

  testWidgets('screen owns display sleep instead of the video plugin', (tester) async {
    await mount(tester);
    final player = tester.widget<VideoPlayer>(find.byType(VideoPlayer)).controller;
    expect(player.videoPlayerOptions?.preventsDisplaySleepDuringVideoPlayback, isFalse);
    expect(awakeCalls.last, isTrue);
    await unmount(tester);
    expect(awakeCalls.last, isFalse);
  });

  testWidgets('unexpected source error stays safe and remote retry can initialize video', (tester) async {
    final pending = Completer<Result<PlaybackSession, Failure>>();
    repository.pending = pending;
    await pumpTvApp(
      tester,
      const PlayerScreen(animeId: 10938, episodeNumber: 1, title: 'Аниме'),
      overrides: [playbackRepositoryProvider.overrideWithValue(repository)],
      wrapInScaffold: false,
    );
    await tester.pump();
    pending.completeError(StateError('https://cdn.test/hls?signature=private-value'));
    await settle(tester);
    expect(find.text('Не удалось загрузить видео. Повторите попытку или вернитесь к сериалу.'), findsOneWidget);
    expect(find.textContaining('private-value'), findsNothing);
    expect(repository.calls, 2);
    repository.pending = null;
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await settle(tester);
    expect(find.byType(PlayerView), findsOneWidget);
    // The third request is the explicit recovery after the bounded refresh.
    expect(repository.calls, 3);
    await unmount(tester);
  });

  for (final direction in [LogicalKeyboardKey.arrowRight, LogicalKeyboardKey.arrowLeft]) {
    testWidgets('short $direction previews before one release seek without pause or play', (tester) async {
      await mount(tester);
      final controller = tester.widget<VideoPlayer>(find.byType(VideoPlayer)).controller;
      video.positions[1] = const Duration(seconds: 100);
      controller.value = controller.value.copyWith(position: const Duration(seconds: 100));
      final plays = video.playCalls.length;
      final pauses = video.pauseCalls.length;
      final target = direction == LogicalKeyboardKey.arrowRight ? 110 : 90;
      await tester.sendKeyDownEvent(direction);
      await tester.pump(const Duration(milliseconds: 499));
      expect(video.seekRequests, isEmpty);
      expect(previewSeconds(tester), target);
      expect(controller.value.position, const Duration(seconds: 100));
      expect(find.text('01:${target == 110 ? '50' : '30'} / 24:00'), findsOneWidget);
      await tester.sendKeyUpEvent(direction);
      await tester.pump(const Duration(seconds: 2));
      expect(video.seekRequests, [Duration(seconds: target)]);
      expect(video.playCalls, hasLength(plays));
      expect(video.pauseCalls, hasLength(pauses));
      await unmount(tester);
    });

    testWidgets('held $direction has exact 500ms acceleration boundaries and ignores OS repeats', (tester) async {
      await mount(tester);
      final controller = tester.widget<VideoPlayer>(find.byType(VideoPlayer)).controller;
      video.positions[1] = const Duration(seconds: 720);
      controller.value = controller.value.copyWith(position: const Duration(seconds: 720));
      final sign = direction == LogicalKeyboardKey.arrowRight ? 1 : -1;
      await tester.sendKeyDownEvent(direction);
      await tester.pump();
      var target = sign * 10 + 720;
      // Explicit oracle: ticks at 2/4/6/8 seconds start each new acceleration interval.
      const steps = [10, 10, 10, 20, 20, 20, 20, 30, 30, 30, 30, 60, 60, 60, 60, 120, 120];
      for (final step in steps) {
        for (var repeat = 0; repeat < 3; repeat++) {
          await tester.sendKeyRepeatEvent(direction);
        }
        await tester.pump(const Duration(milliseconds: 499));
        expect(previewSeconds(tester), target);
        expect(video.seekRequests, isEmpty);
        await tester.pump(const Duration(milliseconds: 1));
        target = (target + sign * step).clamp(0, 1440);
        expect(previewSeconds(tester), target);
        expect(video.seekRequests, isEmpty);
        expect(controlsVisible(tester), isTrue);
      }
      await tester.sendKeyUpEvent(direction);
      await tester.pump();
      expect(video.seekRequests, [Duration(seconds: target)]);
      await tester.pump(const Duration(milliseconds: 3999));
      expect(controlsVisible(tester), isTrue);
      await tester.pump(const Duration(milliseconds: 1));
      expect(controlsVisible(tester), isFalse);
      await unmount(tester);
    });
  }

  testWidgets('direction changes continue the draft and reset acceleration while old key up is ignored', (
    tester,
  ) async {
    await mount(tester);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
    for (var tick = 0; tick < 12; tick++) {
      await tester.pump(const Duration(milliseconds: 500));
    }
    expect(previewSeconds(tester), 300);
    expect(video.seekRequests, isEmpty);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(previewSeconds(tester), 290);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump(const Duration(milliseconds: 500));
    expect(previewSeconds(tester), 280);
    expect(video.seekRequests, isEmpty);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(video.seekRequests, [const Duration(seconds: 280)]);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump(const Duration(milliseconds: 500));
    expect(previewSeconds(tester), 300);
    expect(video.seekRequests, hasLength(1));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(video.seekRequests, [const Duration(seconds: 280), const Duration(seconds: 300)]);
    await unmount(tester);
  });

  testWidgets('seek draft clamps and identical release targets do not add native calls', (tester) async {
    await mount(tester);
    final controller = tester.widget<VideoPlayer>(find.byType(VideoPlayer)).controller;
    await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowLeft);
    for (var tick = 0; tick < 18; tick++) {
      await tester.pump(const Duration(milliseconds: 500));
    }
    expect(previewSeconds(tester), 0);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowLeft);
    expect(video.seekRequests, isEmpty);
    controller.value = controller.value.copyWith(position: controller.value.duration - const Duration(seconds: 5));
    await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump(const Duration(seconds: 5));
    expect(previewSeconds(tester), 1440);
    expect(video.seekRequests, isEmpty);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(video.seekRequests, [controller.value.duration]);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(video.seekRequests, [controller.value.duration]);
    await unmount(tester);
  });

  testWidgets('a draft returning to the confirmed or pending target adds no native command', (tester) async {
    await mount(tester);
    final controller = tester.widget<VideoPlayer>(find.byType(VideoPlayer)).controller;
    video.positions[1] = const Duration(seconds: 100);
    controller.value = controller.value.copyWith(position: const Duration(seconds: 100));
    await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(video.seekRequests, isEmpty);
    final gate = Completer<void>();
    video.pendingSeek = gate;
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(video.seekRequests, [const Duration(seconds: 110)]);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    video.pendingSeek = null;
    gate.complete();
    await tester.pump();
    expect(video.seekRequests, [const Duration(seconds: 110)]);
    await unmount(tester);
  });

  testWidgets('native position ticks cannot overwrite draft time or slider', (tester) async {
    await mount(tester);
    final controller = tester.widget<VideoPlayer>(find.byType(VideoPlayer)).controller;
    controller.value = controller.value.copyWith(position: const Duration(seconds: 100));
    await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    controller.value = controller.value.copyWith(position: const Duration(seconds: 103));
    await tester.pump();
    expect(controller.value.position, const Duration(seconds: 103));
    expect(previewSeconds(tester), 110);
    expect(find.text('01:50 / 24:00'), findsOneWidget);
    expect(video.seekRequests, isEmpty);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(video.seekRequests, [const Duration(seconds: 110)]);
    await unmount(tester);
  });

  testWidgets('rapid complete gestures base on pending target and serialize coalesced native seeks', (tester) async {
    await mount(tester);
    final gate = Completer<void>();
    video.pendingSeek = gate;
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(video.seekRequests, [const Duration(seconds: 10)]);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(previewSeconds(tester), 30);
    expect(video.seekRequests, [const Duration(seconds: 10)]);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    video.pendingSeek = null;
    gate.complete();
    await tester.pump();
    expect(video.seeks, [const Duration(seconds: 10), const Duration(seconds: 30)]);
    expect(video.maxActiveSeeks, 1);
    await unmount(tester);
  });

  testWidgets('timeline short gestures commit only on release and row buttons still seek directly', (tester) async {
    await mount(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'Позиция видео');
    await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(previewSeconds(tester), 10);
    expect(video.seekRequests, isEmpty);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(video.seekRequests, [const Duration(seconds: 10)]);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(previewSeconds(tester), 0);
    expect(video.seekRequests, hasLength(1));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(video.seekRequests, [const Duration(seconds: 10), Duration.zero]);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'Пауза / воспроизведение');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'Назад на 10 секунд');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'Вперёд на 10 секунд');
    expect(video.seekRequests, hasLength(2));
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pump();
    expect(video.seekRequests.last, const Duration(seconds: 10));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pump();
    expect(video.seekRequests, [
      const Duration(seconds: 10),
      Duration.zero,
      const Duration(seconds: 10),
      Duration.zero,
    ]);
    await unmount(tester);
  });

  testWidgets('timeline uses the same hold and leaving it cancels repeat without changing button navigation', (
    tester,
  ) async {
    await mount(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'Позиция видео');
    await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
    for (var tick = 0; tick < 4; tick++) {
      await tester.pump(const Duration(milliseconds: 500));
    }
    expect(previewSeconds(tester), 60);
    expect(video.seekRequests, isEmpty);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    final requests = video.seeks.length;
    await tester.pump(const Duration(seconds: 1));
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'Назад на 10 секунд');
    await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'Вперёд на 10 секунд');
    expect(video.seeks, hasLength(requests));
    expect(tester.widget<PlayerView>(find.byType(PlayerView)).previewPosition, isNull);
    await unmount(tester);
  });

  testWidgets('Back during hold cancels repeats before the player route finishes closing', (tester) async {
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
    await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump(const Duration(milliseconds: 500));
    final requests = video.seekRequests.length;
    expect(video.seekRequests, isEmpty);
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(awakeCalls.last, isFalse);
    await tester.pump(const Duration(seconds: 1));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowRight);
    await settle(tester);
    expect(video.seekRequests, hasLength(requests));
    expect(find.byType(PlayerScreen), findsNothing);
    expect(video.disposed, [1]);
    expect(awakeCalls.last, isFalse);
    await unmount(tester);
  });

  testWidgets('background and disposal while holding cancel repeat', (tester) async {
    await mount(tester);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump(const Duration(milliseconds: 500));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    final requests = video.seekRequests.length;
    await tester.pump(const Duration(seconds: 2));
    expect(video.seekRequests, hasLength(requests));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowRight);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    final beforeDispose = video.seekRequests.length;
    expect(video.seekRequests, isEmpty);
    await unmount(tester);
    await tester.pump(const Duration(seconds: 2));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowLeft);
    expect(video.seekRequests, hasLength(beforeDispose));
  });

  for (final cause in ['focus', 'command', 'panel', 'background', 'error', 'replacement']) {
    testWidgets('$cause cancels draft and late key up or timer cannot commit it', (tester) async {
      await mount(tester);
      final controller = tester.widget<VideoPlayer>(find.byType(VideoPlayer)).controller;
      video.positions[1] = const Duration(seconds: 100);
      controller.value = controller.value.copyWith(position: const Duration(seconds: 100));
      await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump(const Duration(milliseconds: 500));
      expect(previewSeconds(tester), 120);
      expect(video.seekRequests, isEmpty);
      switch (cause) {
        case 'focus':
          // External focus loss exercises the focus listener without a key command.
          tester.widget<PlayerView>(find.byType(PlayerView)).playFocusNode?.requestFocus();
          await tester.pump();
          await tester.pump();
          expect(FocusManager.instance.primaryFocus?.debugLabel, 'Пауза / воспроизведение');
        case 'command':
          await tester.sendKeyEvent(LogicalKeyboardKey.mediaPause);
          await tester.pump();
        case 'panel':
          await tester.tap(find.byKey(const ValueKey('player-quality')));
          await settle(tester);
          expect(find.text('Качество видео'), findsOneWidget);
        case 'background':
          tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
          await tester.pump();
        case 'error':
          controller.value = controller.value.copyWith(errorDescription: 'Simulated playback error');
          await settle(tester);
          expect(video.sources, hasLength(2));
        case 'replacement':
          await tester.tap(find.byKey(const ValueKey('player-next-episode')));
          await settle(tester);
          expect(video.sources, hasLength(2));
      }
      final recoverySeeks = List<Duration>.of(video.seekRequests);
      // Recovery may restore confirmed 100s. The cancelled 120s must never be submitted.
      expect(recoverySeeks, cause == 'error' ? [const Duration(seconds: 100)] : isEmpty);
      expect(tester.widget<PlayerView>(find.byType(PlayerView)).previewPosition, isNull);
      expect(previewSeconds(tester), cause == 'replacement' ? 0 : 100);
      await tester.pump(const Duration(seconds: 2));
      await tester.sendKeyRepeatEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(video.seekRequests, recoverySeeks);
      expect(tester.widget<PlayerView>(find.byType(PlayerView)).previewPosition, isNull);
      if (cause == 'background') {
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        await tester.pump();
      }
      await unmount(tester);
    });
  }

  testWidgets('paused hold remains paused and release keeps controls visible', (tester) async {
    await mount(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.mediaPause);
    await tester.pump();
    final controller = tester.widget<VideoPlayer>(find.byType(VideoPlayer)).controller;
    final plays = video.playCalls.length;
    final pauses = video.pauseCalls.length;
    await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
    for (var tick = 0; tick < 10; tick++) {
      await tester.pump(const Duration(milliseconds: 500));
    }
    expect(video.seekRequests, isEmpty);
    expect(controlsVisible(tester), isTrue);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump(const Duration(seconds: 6));
    expect(video.seekRequests, [const Duration(seconds: 210)]);
    expect(controller.value.isPlaying, isFalse);
    expect(video.playCalls, hasLength(plays));
    expect(video.pauseCalls, hasLength(pauses));
    expect(controlsVisible(tester), isTrue);
    await unmount(tester);
  });

  testWidgets('old native result cannot drain queued gestures into replacement controller', (tester) async {
    await mount(tester);
    final gate = Completer<void>();
    video.pendingSeek = gate;
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(previewSeconds(tester), 30);
    await tester.tap(find.byKey(const ValueKey('player-next-episode')));
    await settle(tester);
    expect(video.sources, hasLength(2));
    video.pendingSeek = null;
    gate.complete();
    await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump(const Duration(seconds: 1));
    expect(video.seekRequests, [const Duration(seconds: 10)]);
    expect(video.positions[2] ?? Duration.zero, Duration.zero);
    expect(tester.widget<PlayerView>(find.byType(PlayerView)).previewPosition, isNull);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(video.seekRequests, [const Duration(seconds: 10), const Duration(seconds: 10)]);
    expect(video.maxActiveSeeks, 1);
    await unmount(tester);
  });

  for (final key in [LogicalKeyboardKey.arrowDown, LogicalKeyboardKey.arrowUp]) {
    testWidgets('controls hide after idle with focus on ${key == LogicalKeyboardKey.arrowUp ? 'Back' : 'Play'}', (
      tester,
    ) async {
      await mount(tester);
      await tester.sendKeyEvent(key);
      await tester.pump();
      await tester.pump();
      expect(
        FocusManager.instance.primaryFocus?.debugLabel,
        key == LogicalKeyboardKey.arrowUp ? 'К сериям' : 'Пауза / воспроизведение',
      );
      await tester.pump(const Duration(seconds: 3));
      expect(controlsVisible(tester), isTrue);
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      expect(controlsVisible(tester), isFalse);
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'Видео');
      await tester.sendKeyEvent(key);
      await tester.pump();
      await tester.pump();
      expect(controlsVisible(tester), isTrue);
      expect(
        FocusManager.instance.primaryFocus?.debugLabel,
        key == LogicalKeyboardKey.arrowUp ? 'К сериям' : 'Пауза / воспроизведение',
      );
      await unmount(tester);
    });
  }

  testWidgets('button navigation repeat and boundary presses renew idle timer', (tester) async {
    await mount(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump(const Duration(seconds: 3));
    expect(controlsVisible(tester), isTrue);
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump(const Duration(seconds: 3));
    expect(controlsVisible(tester), isTrue);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump(const Duration(seconds: 4));
    expect(controlsVisible(tester), isFalse);
    expect(video.seeks, isEmpty);
    await unmount(tester);
  });

  testWidgets('pause focus change and resume hide only after renewed playing inactivity', (tester) async {
    await mount(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pump();
    await tester.pump(const Duration(seconds: 6));
    expect(controlsVisible(tester), isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'К сериям');
    await tester.pump(const Duration(seconds: 6));
    expect(controlsVisible(tester), isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.mediaPlay);
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    expect(controlsVisible(tester), isTrue);
    await tester.pump(const Duration(seconds: 1));
    expect(controlsVisible(tester), isFalse);
    await unmount(tester);
  });

  testWidgets('episode reload during hold cancels repeats and does not seek the replacement controller', (
    tester,
  ) async {
    await mount(tester);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.byKey(const ValueKey('player-next-episode')));
    await settle(tester);
    final requests = video.seekRequests.length;
    await tester.pump(const Duration(seconds: 2));
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowRight);
    expect(video.seekRequests, hasLength(requests));
    expect(video.sources, hasLength(2));
    expect(video.positions[2] ?? Duration.zero, Duration.zero);
    await unmount(tester);
  });

  testWidgets('chooser focus cannot seek background video and restarts hide timer on return', (tester) async {
    await mount(tester);
    await openMenu(tester);
    final requests = video.seekRequests.length;
    await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump(const Duration(seconds: 5));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowRight);
    expect(video.seekRequests, hasLength(requests));
    expect(controlsVisible(tester), isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await settle(tester);
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'Видео');
    await tester.pump(const Duration(seconds: 4));
    expect(controlsVisible(tester), isFalse);
    await unmount(tester);
  });

  testWidgets('a late native seek after disposal cannot drain pending hold targets', (tester) async {
    await mount(tester);
    final gate = Completer<void>();
    video.pendingSeek = gate;
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpWidget(const SizedBox());
    video.pendingSeek = null;
    gate.complete();
    await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowRight);
    await settle(tester);
    expect(video.seekRequests, [const Duration(seconds: 10)]);
    expect(video.disposed, [1]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('screen flag follows play pause resume and native stop without position polling', (tester) async {
    await mount(tester);
    expect(awakeCalls, [false, true]);
    await tester.sendKeyEvent(LogicalKeyboardKey.mediaPause);
    await tester.pump();
    expect(awakeCalls.last, isFalse);
    await tester.sendKeyEvent(LogicalKeyboardKey.mediaPlay);
    await tester.pump();
    expect(awakeCalls.last, isTrue);
    video.events[1]!.add(
      platform.VideoEvent(eventType: platform.VideoEventType.isPlayingStateUpdate, isPlaying: false),
    );
    await tester.pump();
    expect(awakeCalls.last, isFalse);
    await tester.pumpWidget(const SizedBox());
    await settle(tester);
  });

  testWidgets('buffering releases the flag and only playing bufferingEnd restores it', (tester) async {
    await mount(tester);
    video.events[1]!.add(platform.VideoEvent(eventType: platform.VideoEventType.bufferingStart));
    await tester.pump();
    expect(awakeCalls.last, isFalse);
    video.events[1]!.add(platform.VideoEvent(eventType: platform.VideoEventType.bufferingEnd));
    await tester.pump();
    expect(awakeCalls.last, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.mediaPause);
    await tester.pump();
    video.events[1]!.add(platform.VideoEvent(eventType: platform.VideoEventType.bufferingEnd));
    await tester.pump();
    expect(awakeCalls.last, isFalse);
    await tester.pumpWidget(const SizedBox());
    await settle(tester);
  });

  testWidgets('inactive hidden paused detached and resume never retain a stale flag', (tester) async {
    await mount(tester);
    for (final state in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
      AppLifecycleState.detached,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
      await tester.pump();
      expect(awakeCalls.last, isFalse, reason: state.name);
    }
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await settle(tester);
    expect(awakeCalls.last, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.mediaPause);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await settle(tester);
    expect(awakeCalls.last, isFalse);
    await tester.pumpWidget(const SizedBox());
    await settle(tester);
  });

  testWidgets('late initialization in background cannot hold the screen before foreground playback', (tester) async {
    video.delayInitialization = true;
    await pumpTvApp(
      tester,
      const PlayerScreen(animeId: 10938, episodeNumber: 1, title: 'Аниме'),
      overrides: [playbackRepositoryProvider.overrideWithValue(repository)],
      wrapInScaffold: false,
    );
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    expect(awakeCalls, [false]);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    video.events[1]!.add(
      platform.VideoEvent(
        eventType: platform.VideoEventType.initialized,
        duration: const Duration(minutes: 24),
        size: const Size(1280, 720),
      ),
    );
    await settle(tester);
    expect(video.playCalls, isEmpty, reason: 'Late initialization must not start playback in the background');
    // Background initialization must still leave the initial flag disabled.
    // ignore: avoid-duplicate-test-assertions
    expect(awakeCalls, [false]);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(awakeCalls.last, isTrue);
    await tester.pumpWidget(const SizedBox());
    await settle(tester);
    expect(awakeCalls.last, isFalse);
  });

  testWidgets('ordinary pages and pop transitions release immediately across repeated player entries', (tester) async {
    await pumpTvApp(
      tester,
      const Text('Каталог'),
      overrides: [playbackRepositoryProvider.overrideWithValue(repository)],
    );
    final navigator = Navigator.of(tester.element(find.text('Каталог')));
    expect(awakeCalls, isEmpty);
    for (var i = 0; i < 2; i++) {
      unawaited(
        navigator.push(
          MaterialPageRoute<void>(builder: (_) => const PlayerScreen(animeId: 10938, episodeNumber: 1, title: 'Аниме')),
        ),
      );
      await settle(tester);
      expect(awakeCalls.last, isTrue);
      unawaited(navigator.push(MaterialPageRoute<void>(builder: (_) => const Text('Обычный экран'))));
      await tester.pump();
      expect(awakeCalls.last, isFalse);
      await settle(tester);
      navigator.pop();
      await settle(tester);
      expect(awakeCalls.last, isTrue);
      navigator.pop();
      await tester.pump();
      expect(awakeCalls.last, isFalse, reason: 'release before reverse transition disposes player');
      await settle(tester);
      expect(find.text('Каталог'), findsOneWidget);
    }
    await tester.pumpWidget(const SizedBox());
    await settle(tester);
    expect(video.disposed, [1, 2]);
  });

  testWidgets('channel failure cannot fail playback or leave an unhandled async error', (tester) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(awakeChannel, (_) async {
      throw PlatformException(code: 'ScreenFlagError');
    });
    await mount(tester);
    expect(tester.widget<VideoPlayer>(find.byType(VideoPlayer)).controller.value.isPlaying, isTrue);
    expect(repository.calls, 1);
    await tester.sendKeyEvent(LogicalKeyboardKey.mediaPause);
    await tester.pumpWidget(const SizedBox());
    await settle(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('next and previous replace native playback at zero keeping quality and respecting edges', (tester) async {
    repository.episodeNumbers = [3, 1];
    await mount(tester);
    final first = tester.widget<VideoPlayer>(find.byType(VideoPlayer)).controller;
    await first.seekTo(const Duration(seconds: 40));
    expect(find.byKey(const ValueKey('player-previous-episode')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('player-next-episode')));
    await tester.pump();
    expect(awakeCalls.last, isFalse);
    await settle(tester);
    final second = tester.widget<VideoPlayer>(find.byType(VideoPlayer)).controller;
    expect(repository.episode, 3);
    expect(awakeCalls.last, isTrue);
    expect(second, isNot(same(first)));
    expect(second.value.position, Duration.zero);
    expect(repository.quality, PlaybackQuality.high);
    expect(find.byKey(const ValueKey('player-next-episode')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('player-previous-episode')));
    await settle(tester);
    expect(repository.episode, 1);
    expect(repository.calls, 3);
    await tester.pumpWidget(const SizedBox());
    await settle(tester);
  });

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

  testWidgets('hidden controls reveal focus and hide again after pause resume without navigation seeks', (
    tester,
  ) async {
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
    await tester.pump();
    expect(tester.widget<PlayerView>(find.byType(PlayerView)).controlsVisible, isFalse);
    expect(controller.value.position, Duration.zero);
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'Видео');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.pump();
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'Пауза / воспроизведение');
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
    expect(awakeCalls.last, isFalse);
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
    await tester.tap(find.text('SD 360p'));
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
    expect(awakeCalls.last, isFalse);
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
    expect(awakeCalls.last, isFalse);
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
    expect(awakeCalls, [false]);
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
    await tester.pump();
    expect(awakeCalls.last, isFalse);
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
    expect(awakeCalls.last, isFalse);
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
    // Recheck after disposal, following the earlier runtime error.
    // ignore: avoid-duplicate-test-assertions
    expect(awakeCalls.last, isFalse);
    expect(native.disposed, [1, 2, 3]);
  });

  testWidgets('persistent initialization failure has two attempts and a manual retry', (tester) async {
    final native = video;
    final repo = repository;
    native.failInitialization = true;
    await mount(tester);
    expect(repo.calls, 2);
    expect(awakeCalls.last, isFalse);
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
    await tester.pump();
    expect(awakeCalls.last, isFalse);
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
