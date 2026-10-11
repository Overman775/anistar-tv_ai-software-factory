// Pumps observe successive native notifications; the private widget is a test fixture.
// ignore_for_file: prefer-moving-to-variable, prefer-match-file-name

import 'package:anistar_tv/packages/features/player/domain/models/playback_quality.dart';
import 'package:anistar_tv/packages/features/player/domain/models/playback_session.dart';
import 'package:anistar_tv/packages/features/player/presentation/widgets/player_overlay.dart';
import 'package:anistar_tv/packages/features/player/presentation/widgets/player_retry_view.dart';
import 'package:anistar_tv/packages/features/player/presentation/widgets/player_view.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:video_player/video_player.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import '../../../../../mocks/features/player/fake_video_platform.dart';
import '../../../../../support/test_app.dart';

void main() {
  late VideoPlayerController controller;
  setUp(() async {
    VideoPlayerPlatform.instance = FakeVideoPlatform();
    controller = VideoPlayerController.networkUrl(Uri.parse('https://fixture.test/video.m3u8'));
    await controller.initialize();
  });
  tearDown(() async => controller.dispose());

  testWidgets('hidden controls avoid position rebuilds and reveal the current timeline', (tester) async {
    await pumpTvApp(tester, _TestPlayerView(controller, visible: false));
    var builds = 0;
    final previousCallback = debugOnRebuildDirtyWidget;
    debugOnRebuildDirtyWidget = (element, builtOnce) {
      previousCallback?.call(element, builtOnce);
      if (element.widget is PlayerOverlay) {
        builds++;
      }
    };
    addTearDown(() => debugOnRebuildDirtyWidget = previousCallback);
    for (var i = 1; i <= 120; i++) {
      controller.value = controller.value.copyWith(
        position: Duration(milliseconds: i * 100),
        buffered: [DurationRange(Duration.zero, Duration(seconds: i))],
      );
      await tester.pump(const Duration(milliseconds: 16));
    }
    debugPrint('OPTIMIZE hidden overlay: $builds builds for 120 position/buffer notifications');
    const baseline = bool.fromEnvironment('OPTIMIZE_BASELINE');
    expect(builds, baseline ? 120 : 0);
    await pumpTvApp(tester, _TestPlayerView(controller, visible: true));
    final overlay = tester.widget<PlayerOverlay>(find.byType(PlayerOverlay));
    expect(overlay.value.position, const Duration(seconds: 12));
    expect(find.text('00:12 / 24:00'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('hidden video still reacts to buffering and errors', (tester) async {
    await pumpTvApp(tester, _TestPlayerView(controller, visible: false));
    controller.value = controller.value.copyWith(isBuffering: true);
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    controller.value = controller.value.copyWith(isBuffering: false);
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    controller.value = controller.value.copyWith(errorDescription: 'Native source failed');
    await tester.pump();
    expect(find.byType(PlayerRetryView), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('visible controls update time and play state', (tester) async {
    await pumpTvApp(tester, _TestPlayerView(controller, visible: true));
    controller.value = controller.value.copyWith(position: const Duration(seconds: 8), isPlaying: true);
    await tester.pump();
    expect(find.text('00:08 / 24:00'), findsOneWidget);
    expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
    controller.value = controller.value.copyWith(isPlaying: false);
    await tester.pump();
    expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
  });

  testWidgets('hidden video updates aspect ratio when native dimensions change', (tester) async {
    await pumpTvApp(tester, _TestPlayerView(controller, visible: false));
    controller.value = controller.value.copyWith(size: const Size(640, 480));
    await tester.pump();
    expect(tester.widget<AspectRatio>(find.byType(AspectRatio)).aspectRatio, 4 / 3);
  });

  testWidgets('controller replacement removes the old listener and disposal removes the new one', (tester) async {
    await pumpTvApp(tester, _TestPlayerView(controller, visible: true));
    final replacement = VideoPlayerController.networkUrl(Uri.parse('https://fixture.test/next.m3u8'));
    addTearDown(replacement.dispose);
    await tester.runAsync(replacement.initialize);
    replacement.value = replacement.value.copyWith(position: const Duration(seconds: 9));
    await pumpTvApp(tester, _TestPlayerView(replacement, visible: true));
    expect(find.text('00:09 / 24:00'), findsOneWidget);
    // ignore: invalid_use_of_protected_member -- Verify listener ownership after replacement.
    expect(controller.hasListeners, isFalse);
    controller.value = controller.value.copyWith(errorDescription: 'Old source failed');
    await tester.pump();
    expect(find.byType(PlayerRetryView), findsNothing);
    await tester.pumpWidget(const SizedBox());
    // ignore: invalid_use_of_protected_member -- Verify cleanup when the view unmounts.
    expect(replacement.hasListeners, isFalse);
    expect(tester.takeException(), isNull);
  });
}

class _TestPlayerView extends StatelessWidget {
  const _TestPlayerView(this.controller, {required this.visible});

  final VideoPlayerController controller;
  final bool visible;

  @override
  Widget build(BuildContext context) => PlayerView(
    controller: controller,
    controlsVisible: visible,
    episodeNumber: 1,
    title: 'Тестовое аниме',
    session: PlaybackSession(
      manifestUri: Uri.parse('https://fixture.test/video.m3u8'),
      requestedQuality: PlaybackQuality.high,
      selectedQuality: PlaybackQuality.high,
      availableQualities: const [PlaybackQuality.high],
    ),
    onPlayPause: () => fail('Unexpected play command'),
    onSelectQuality: () => fail('Unexpected quality command'),
    onSelectEpisode: () => fail('Unexpected episode command'),
    onRetry: () => fail('Unexpected retry'),
    onSeek: (_) => fail('Unexpected seek'),
    onShowControls: () => fail('Unexpected touch'),
  );
}
