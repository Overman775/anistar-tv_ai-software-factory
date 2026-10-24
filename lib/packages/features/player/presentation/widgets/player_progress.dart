import 'package:video_player/video_player.dart';

String formatPlayerTime(Duration value) {
  final minutes = value.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');

  return value.inHours > 0 ? '${value.inHours}:$minutes:$seconds' : '$minutes:$seconds';
}

int playerSliderMaximum(Duration duration) => duration.inMilliseconds > 0 ? duration.inMilliseconds : 1;

int playerSliderPosition(Duration position, Duration duration) =>
    position.inMilliseconds.clamp(0, playerSliderMaximum(duration));

int playerSeekPosition(Duration position, Duration duration) =>
    position.inMilliseconds.clamp(0, duration.inMilliseconds > 0 ? duration.inMilliseconds : 0);

int playerBufferedPosition(Iterable<DurationRange> ranges, Duration duration) {
  final buffered = ranges.fold<int>(
    0,
    (maximum, range) => range.end.inMilliseconds > maximum ? range.end.inMilliseconds : maximum,
  );

  return buffered.clamp(0, playerSliderMaximum(duration));
}
