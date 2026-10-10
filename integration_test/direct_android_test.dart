// Native playback changes between awaits: pumps and fresh controller snapshots
// must be repeated rather than cached across those transitions.
// ignore_for_file: prefer-moving-to-variable

import 'package:anistar_tv/main_dev.dart' as app;
import 'package:anistar_tv/packages/features/anime/presentation/screens/anime_screen.dart';
import 'package:anistar_tv/packages/features/catalog/presentation/widgets/anime_card.dart';
import 'package:anistar_tv/packages/features/player/presentation/screens/player_screen.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:video_player/video_player.dart';

/// Live network smoke, deliberately separate from deterministic unit tests.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Android direct catalog → anime → HLS → quality → episode → back', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await app.main();
    final card = find.byWidgetPredicate((widget) => widget is AnimeCard && widget.anime.id == 10938);
    await _wait(tester, () => card.evaluate().isNotEmpty, 'anime 10938 in live catalog');
    await tester.ensureVisible(card);
    await tester.tap(card);
    final playFirst = find.text('Смотреть серию 1');
    await _wait(tester, () => playFirst.evaluate().isNotEmpty, 'anime details and episodes');
    await tester.ensureVisible(playFirst);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(playFirst);
    await _wait(tester, () => _player(tester)?.value.isInitialized ?? false, '720p initialization');
    var player = _requirePlayer(tester);
    expect(player.formatHint, VideoFormat.hls);
    expect(player.httpHeaders['Referer'], contains('id=10938'));
    await _wait(tester, () => player.value.position.inMilliseconds > 1000, '720p playback');
    expect(player.value.size.height, 720);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await _wait(tester, () => player.value.position.inSeconds >= 10, 'remote seek');
    await player.seekTo(const Duration(seconds: 120));
    await _wait(tester, () => player.value.position.inSeconds >= 121, 'seek and resume');
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pump(const Duration(seconds: 1));
    expect(player.value.isPlaying, isFalse);
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await _wait(tester, () => player.value.isPlaying, 'remote resume');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await _wait(tester, () => find.text('360p').evaluate().isNotEmpty, 'quality dialog');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    final previous = player;
    await _wait(tester, () => _player(tester) != null && !identical(_player(tester), previous), 'quality replacement');
    player = _requirePlayer(tester);
    await _wait(tester, () => player.value.position.inSeconds >= 121, '360p preserves seek position');
    expect(player.value.size.height, 360);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await _wait(tester, () => find.text('Серия 2').evaluate().isNotEmpty, 'episode dialog');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    final firstEpisode = player;
    await _wait(
      tester,
      () => _player(tester) != null && !identical(_player(tester), firstEpisode),
      'episode replacement',
    );
    player = _requirePlayer(tester);
    await _wait(tester, () => player.value.position.inMilliseconds > 1000, 'episode 2 start');
    expect(player.value.position.inSeconds, lessThan(30));
    expect(player.value.hasError, isFalse);
    await tester.binding.handlePopRoute();
    await _wait(tester, () => find.byType(PlayerScreen).evaluate().isEmpty, 'back from player');
    expect(find.byType(AnimeScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}

VideoPlayerController? _player(WidgetTester tester) {
  final finder = find.byType(VideoPlayer);

  return finder.evaluate().isEmpty ? null : tester.widget<VideoPlayer>(finder).controller;
}

VideoPlayerController _requirePlayer(WidgetTester tester) =>
    _player(tester) ?? (throw TestFailure('Expected an initialized native player'));

Future<void> _wait(WidgetTester tester, bool Function() condition, String step) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    await tester.pump(const Duration(milliseconds: 500));
    if (condition()) {
      return;
    }
  }
  fail('Timed out waiting for $step');
}
