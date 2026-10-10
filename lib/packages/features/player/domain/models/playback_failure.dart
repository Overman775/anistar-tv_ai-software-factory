import 'package:core/data.dart';

/// A native playback error expressed without transport or signed media details.
final class PlaybackFailure extends Failure {
  const PlaybackFailure({required String message}) : super(message);
}
