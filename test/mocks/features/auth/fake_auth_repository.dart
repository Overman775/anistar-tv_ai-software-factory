import 'dart:async';

import 'package:anistar_tv/packages/features/auth/domain/auth_profile.dart';
import 'package:anistar_tv/packages/features/auth/domain/auth_repository.dart';
import 'package:core/data.dart';

final class FakeAuthRepository implements AuthRepository {
  Result<String?, Failure> restoreResult = const Result.success(null);
  Result<String, Failure> loginResult = const Result.success('test');
  Result<void, Failure> cancellationResult = const Result.success(null);
  Completer<Result<void, Failure>>? pendingCancellation;
  int cancellationCalls = 0;
  RequestCancellation? lastCancelledToken;
  Result<void, Failure> logoutResult = const Result.success(null);
  @override
  Uri profileOrigin = Uri.parse('https://auth.test/');
  Result<AuthProfile, Failure> profileResult = const Result.success(AuthProfile());
  Completer<Result<AuthProfile, Failure>>? pendingProfile;
  Completer<Result<String, Failure>>? pendingLogin;
  Completer<void>? pendingSiteCheck;
  Completer<Result<String?, Failure>>? pendingRestore;
  Failure? siteFailure;
  int restoreCalls = 0;
  int loginCalls = 0;
  RequestCancellation? lastLoginCancellation;
  final StreamController<void> _expired = StreamController<void>.broadcast();

  @override
  Stream<void> get expired => _expired.stream;

  @override
  Future<Result<AuthProfile, Failure>> loadProfile(String account) =>
      pendingProfile?.future ?? Future.value(profileResult);

  @override
  Future<Result<String?, Failure>> restore({void Function()? onSessionCheck}) async {
    restoreCalls++;
    await pendingSiteCheck?.future;
    if (siteFailure case final failure?) {
      return Result.failure(failure);
    }
    onSessionCheck?.call();

    return pendingRestore?.future ?? Future.value(restoreResult);
  }

  @override
  Future<Result<String, Failure>> signIn(String username, String password, {RequestCancellation? cancellation}) {
    loginCalls++;
    lastLoginCancellation = cancellation;

    return pendingLogin?.future ?? Future.value(loginResult);
  }

  @override
  Future<Result<void, Failure>> cancelSignIn(RequestCancellation cancellation) {
    cancellationCalls++;
    lastCancelledToken = cancellation;
    cancellation.cancel();

    return pendingCancellation?.future ?? Future.value(cancellationResult);
  }

  @override
  Future<Result<void, Failure>> signOut() => Future.value(logoutResult);

  void expire() => _expired.add(null);
  Future<void> close() => _expired.close();
}
