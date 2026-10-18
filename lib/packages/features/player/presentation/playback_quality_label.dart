import '../domain/models/playback_quality.dart';

extension PlaybackQualityLabel on PlaybackQuality {
  String get shortLabel => switch (this) {
    PlaybackQuality.low => 'SD',
    PlaybackQuality.high => 'HD',
  };

  String get label => '$shortLabel ${height}p';
}
