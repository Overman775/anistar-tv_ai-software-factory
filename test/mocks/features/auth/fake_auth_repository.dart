import 'dart:async';

import 'package:anistar_tv/packages/features/auth/domain/auth_repository.dart';
import 'package:core/data.dart';

final class FakeAuthRepository implements AuthRepository {
  Result<String?, Failure> restoreResult = const Result.success(null);
  Result<String, Failure> loginResult = const Result.success('test');
  Result<void, Failure> logoutResult = const Result.success(null);
  Completer<Result<String, Failure>>? pendingLogin;
  int loginCalls = 0;
  final StreamController<void> _expired = StreamController<void>.broadcast();

  @override
  Stream<void> get expired => _expired.stream;

  @override
  Future<Result<String?, Failure>> restore() => Future.value(restoreResult);

  @override
  Future<Result<String, Failure>> signIn(String username, String password) {
    loginCalls++;

    return pendingLogin?.future ?? Future.value(loginResult);
  }

  @override
  Future<Result<void, Failure>> signOut() => Future.value(logoutResult);

  void expire() => _expired.add(null);
  Future<void> close() => _expired.close();
}
