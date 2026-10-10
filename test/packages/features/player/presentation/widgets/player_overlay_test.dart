import 'package:anistar_tv/packages/features/player/domain/models/playback_quality.dart';
import 'package:anistar_tv/packages/features/player/domain/models/playback_session.dart';
import 'package:anistar_tv/packages/features/player/presentation/widgets/player_overlay.dart';
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
    await tester.tap(find.byIcon(Icons.forward_10_rounded));
    expect(seekPosition, const Duration(minutes: 10, seconds: 10));
    await tester.tap(find.byIcon(Icons.pause_rounded));
    expect(playPauseCalls, 1);
  });
}
