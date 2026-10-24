import 'package:anistar_tv/packages/features/player/presentation/widgets/player_progress.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player/video_player.dart';

void main() {
  test('formats player time across minute and hour boundaries', () {
    expect(formatPlayerTime(const Duration(seconds: 5)), '00:05');
    expect(formatPlayerTime(const Duration(minutes: 2, seconds: 3)), '02:03');
    expect(formatPlayerTime(const Duration(hours: 1, minutes: 2, seconds: 3)), '1:02:03');
  });

  test('slider and seek positions clamp invalid duration and values', () {
    expect(playerSliderMaximum(Duration.zero), 1);
    expect(playerSliderMaximum(const Duration(seconds: 8)), 8000);
    expect(playerSliderPosition(const Duration(seconds: -1), Duration.zero), 0);
    expect(playerSliderPosition(const Duration(seconds: 12), const Duration(seconds: 8)), 8000);
    expect(playerSeekPosition(const Duration(seconds: -1), const Duration(seconds: 8)), 0);
    expect(playerSeekPosition(const Duration(seconds: 12), const Duration(seconds: 8)), 8000);
    expect(playerSeekPosition(const Duration(seconds: 12), Duration.zero), 0);
  });

  test('buffered position uses the furthest range endpoint and clamps it', () {
    expect(
      playerBufferedPosition([
        DurationRange(const Duration(seconds: 1), const Duration(seconds: 4)),
        DurationRange(const Duration(seconds: 2), const Duration(seconds: 9)),
      ], const Duration(seconds: 8)),
      8000,
    );
    expect(playerBufferedPosition(const [], Duration.zero), 0);
  });
}
