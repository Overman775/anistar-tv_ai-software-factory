import 'package:core/data.dart';

/// An unavailable page, challenge, changed markup or missing AniStar source.
final class AnistarFailure extends Failure {
  const AnistarFailure({required String message}) : super(message);
}
