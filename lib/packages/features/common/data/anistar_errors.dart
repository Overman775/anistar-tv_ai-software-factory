import 'package:anistar/anistar.dart';
import 'package:core/data.dart';
import 'package:networking/networking.dart';

/// Map expected client failures before BaseRepository creates the single Result.
Future<T> mapAnistarErrors<T>(Future<T> Function() request) async {
  try {
    return await request();
  } on AnistarClientException catch (error, stackTrace) {
    final Failure failure = switch (error.category) {
      AnistarClientErrorCategory.timeout => TimeoutFailure(stackTrace: stackTrace),
      AnistarClientErrorCategory.connection => ConnectionFailure(stackTrace: stackTrace),
      AnistarClientErrorCategory.server => ServerFailure(stackTrace: stackTrace),
      AnistarClientErrorCategory.request => RequestFailure(message: error.message, stackTrace: stackTrace),
    };
    Error.throwWithStackTrace(failure, stackTrace);
  }
}
