import 'package:core/data.dart';

import 'auth_profile.dart';

abstract interface class AuthRepository {
  Stream<void> get expired;

  /// Active AniStar origin bound to the authentication context.
  Uri? get profileOrigin;

  Future<Result<String?, Failure>> restore({void Function()? onSessionCheck});
  Future<Result<String, Failure>> signIn(String username, String password, {RequestCancellation? cancellation});
  Future<Result<void, Failure>> cancelSignIn(RequestCancellation cancellation);
  Future<Result<void, Failure>> signOut();
  Future<Result<AuthProfile, Failure>> loadProfile(String account);
}
