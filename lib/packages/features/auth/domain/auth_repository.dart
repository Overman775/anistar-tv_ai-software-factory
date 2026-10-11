import 'package:core/data.dart';

abstract interface class AuthRepository {
  Stream<void> get expired;

  Future<Result<String?, Failure>> restore({void Function()? onSessionCheck});
  Future<Result<String, Failure>> signIn(String username, String password);
  Future<Result<void, Failure>> signOut();
}
