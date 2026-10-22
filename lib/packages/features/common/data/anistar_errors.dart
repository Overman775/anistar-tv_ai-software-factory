import 'package:anistar/anistar.dart';
import 'package:networking/networking.dart';

import '../../auth/domain/auth_invalid_credentials_failure.dart';

/// Map expected client failures before BaseRepository creates the single Result.
Future<T> mapAnistarErrors<T>(Future<T> Function() request) async {
  try {
    return await request();
  } on AnistarClientException catch (error, stackTrace) {
    final failure = switch (error.category) {
      AnistarClientErrorCategory.invalidCredentials => AuthInvalidCredentialsFailure(stackTrace: stackTrace),
      AnistarClientErrorCategory.timeout => TimeoutFailure(stackTrace: stackTrace),
      AnistarClientErrorCategory.connection => ConnectionFailure(stackTrace: stackTrace),
      AnistarClientErrorCategory.server => ServerFailure(stackTrace: stackTrace),
      AnistarClientErrorCategory.request => RequestFailure(message: error.message, stackTrace: stackTrace),
    };
    Error.throwWithStackTrace(failure, stackTrace);
  }
}
