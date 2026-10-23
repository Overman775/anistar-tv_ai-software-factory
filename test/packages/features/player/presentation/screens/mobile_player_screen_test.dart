// Lifecycle pumps and native callback observations must read current state.
import 'dart:async';

import 'package:anistar_tv/packages/features/player/player_providers.dart';
import 'package:anistar_tv/packages/features/player/presentation/screens/player_screen.dart';
import 'package:anistar_tv/packages/features/player/presentation/widgets/player_view.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import '../../../../../mocks/features/player/fake_playback_repository.dart';
import '../../../../../mocks/features/player/fake_video_platform.dart';
import '../../../../../support/test_app.dart';

void main() {
  late FakeVideoPlatform video;
  late FakePlaybackRepository repository;
  late VideoPlayerPlatform previous;
  final platformCalls = <MethodCall>[];
  setUp(() {
    TestWidgetsFlutterBinding.instance.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    previous = VideoPlayerPlatform.instance;
    video = FakeVideoPlatform();
    repository = FakePlaybackRepository();
    VideoPlayerPlatform.instance = video;
    platformCalls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        platformCalls.add(call);

        return null;
      },
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('anistar_tv/playback_screen_awake'),
      (_) async => null,
    );
  });
  tearDown(() {
    VideoPlayerPlatform.instance = previous;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('anistar_tv/playback_screen_awake'),
      null,
    );
  });
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.pump();
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    }
    await tester.pumpAndSettle();
  }

  Future<void> mount(WidgetTester tester) async {
    await pumpMobileApp(
      tester,
      const PlayerScreen(animeId: 10938, episodeNumber: 1, title: 'Аниме'),
      overrides: [playbackRepositoryProvider.overrideWithValue(repository)],
      wrapInScaffold: false,
    );
    await settle(tester);
  }

  testWidgets('rotate changes requested orientation without reopening video and Back restores mobile policy', (
    tester,
  ) async {
    await pumpMobileApp(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const PlayerScreen(animeId: 10938, episodeNumber: 1, title: 'Аниме'),
            ),
          ),
          child: const Text('Открыть видео'),
        ),
      ),
      overrides: [playbackRepositoryProvider.overrideWithValue(repository)],
    );
    await tester.tap(find.text('Открыть видео'));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('player-rotate')));
    await tester.pump();
    expect(platformCalls.where((call) => call.method == 'SystemChrome.setPreferredOrientations').last.arguments, [
      'DeviceOrientation.landscapeLeft',
      'DeviceOrientation.landscapeRight',
    ]);
    expect(video.sources.length, 1);
    tester.view.physicalSize = const Size(844, 390);
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('player-rotate')));
    await tester.pump();
    expect(platformCalls.where((call) => call.method == 'SystemChrome.setPreferredOrientations').last.arguments, [
      'DeviceOrientation.portraitUp',
    ]);
    // Returning to portrait must still reuse the original native source.
    expect(video.sources.length, 1);
    await tester.binding.handlePopRoute();
    await settle(tester);
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
    expect(video.disposed, [1]);
    expect(
      platformCalls.where((call) => call.method == 'SystemChrome.setPreferredOrientations').last.arguments,
      isEmpty,
    );
    expect(
      platformCalls.where((call) => call.method == 'SystemChrome.setEnabledSystemUIMode').last.arguments,
      'SystemUiMode.edgeToEdge',
    );
    expect(find.text('Открыть видео'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('touch reveal and hide preserves paused controls; quality sheet isolates commands and retains state', (
    tester,
  ) async {
    await mount(tester);
    var view = tester.widget<PlayerView>(find.byType(PlayerView));
    expect(view.controller.value.isPlaying, isTrue);
    await tester.tapAt(const Offset(200, 250));
    await tester.pump();
    expect(tester.widget<PlayerView>(find.byType(PlayerView)).controlsVisible, isFalse);
    await tester.tapAt(const Offset(200, 250));
    await tester.pumpAndSettle();
    expect(tester.widget<PlayerView>(find.byType(PlayerView)).controlsVisible, isTrue);
    await tester.tap(find.byKey(const ValueKey('player-play')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 5));
    expect(tester.widget<PlayerView>(find.byType(PlayerView)).controlsVisible, isTrue);
    view = tester.widget<PlayerView>(find.byType(PlayerView));
    await view.controller.seekTo(const Duration(seconds: 30));
    await tester.tap(find.byKey(const ValueKey('player-quality')));
    await settle(tester);
    expect(find.byType(BottomSheet), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.mediaPlay);
    await tester.pump();
    expect(view.controller.value.isPlaying, isFalse);
    await tester.tap(find.text('SD 360p'));
    await settle(tester);
    view = tester.widget<PlayerView>(find.byType(PlayerView));
    expect(view.controller.value.position, const Duration(seconds: 30));
    // Switching quality must preserve the pause verified before selection.
    expect(view.controller.value.isPlaying, isFalse);
    expect(video.sources.length, 2);
    TestWidgetsFlutterBinding.instance.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    TestWidgetsFlutterBinding.instance.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(view.controller.value.isPlaying, isFalse);
    await tester.pumpWidget(const SizedBox());
    await settle(tester);
    expect(tester.takeException(), isNull);
  });
  testWidgets('mobile scrub stays visible during long drag and adjacent episodes reset position', (tester) async {
    repository.episodeNumbers = [1, 3, 5];
    await mount(tester);
    final slider = tester.widget<Slider>(find.byType(Slider));
    slider.onChangeStart?.call(0);
    slider.onChanged?.call(30000);
    await tester.pump();
    await tester.pump(const Duration(seconds: 5));
    expect(tester.widget<PlayerView>(find.byType(PlayerView)).controlsVisible, isTrue);
    slider.onChangeEnd?.call(30000);
    await tester.pump(const Duration(seconds: 5));
    expect(tester.widget<PlayerView>(find.byType(PlayerView)).controlsVisible, isFalse);
    await tester.tapAt(const Offset(200, 250));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('player-next-episode')));
    await settle(tester);
    final view = tester.widget<PlayerView>(find.byType(PlayerView));
    expect(view.episodeNumber, 3);
    expect(view.controller.value.position, Duration.zero);
    expect(video.sources.length, 2);
    await tester.pumpWidget(const SizedBox());
    await settle(tester);
    expect(tester.takeException(), isNull);
  });
  testWidgets('mobile loading and source failure keep a visible return button', (tester) async {
    video.delayInitialization = true;
    await pumpMobileApp(
      tester,
      const PlayerScreen(animeId: 10938, episodeNumber: 1, title: 'Аниме'),
      overrides: [playbackRepositoryProvider.overrideWithValue(repository)],
      wrapInScaffold: false,
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('player-back')), findsOneWidget);
    video.events[1]?.add(
      VideoEvent(
        eventType: VideoEventType.initialized,
        duration: const Duration(minutes: 24),
        size: const Size(1280, 720),
      ),
    );
    await settle(tester);
    await tester.pumpWidget(const SizedBox());
    await settle(tester);
    video
      ..delayInitialization = false
      ..failInitialization = true;
    await mount(tester);
    expect(find.text('Видео не запустилось'), findsOneWidget);
    // Return must remain available after failure, as it was during loading.
    expect(find.byKey(const ValueKey('player-back')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await settle(tester);
    expect(tester.takeException(), isNull);
  });
  testWidgets('rapid touch seek taps accumulate while native seek is pending', (tester) async {
    await mount(tester);
    final gate = Completer<void>();
    video.pendingSeek = gate;
    for (var tap = 0; tap < 3; tap++) {
      await tester.tap(find.byKey(const ValueKey('player-forward')));
      await tester.pump();
    }
    expect(video.seekRequests, [const Duration(seconds: 10)]);
    video.pendingSeek = null;
    gate.complete();
    await settle(tester);
    expect(video.seeks, [const Duration(seconds: 10), const Duration(seconds: 30)]);
    expect(video.maxActiveSeeks, 1);
    final reverseGate = Completer<void>();
    video.pendingSeek = reverseGate;
    for (var tap = 0; tap < 3; tap++) {
      await tester.tap(find.byKey(const ValueKey('player-rewind')));
      await tester.pump();
    }
    expect(video.seekRequests.last, const Duration(seconds: 20));
    video.pendingSeek = null;
    reverseGate.complete();
    await settle(tester);
    expect(video.seeks.last, Duration.zero);
    // Reverse seeks must be serialized independently of the forward sequence.
    expect(video.maxActiveSeeks, 1);
    await tester.pumpWidget(const SizedBox());
    await settle(tester);
    expect(tester.takeException(), isNull);
  });
}
