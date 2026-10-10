import 'package:anistar/anistar.dart';
import 'package:core/data.dart';
import 'package:dio/dio.dart';
import 'package:networking/networking.dart';

import '../domain/auth_repository.dart';

final class AnistarAuthRepository extends BaseRepository implements AuthRepository {
  final AnistarAuthService _service;

  @override
  Stream<void> get expired => _service.session.expired;

  AnistarAuthRepository(this._service);

  @override
  Future<Result<String?, Failure>> restore() => makeApiCall(() => _safe(_service.restore));

  @override
  Future<Result<String, Failure>> signIn(String username, String password) =>
      makeApiCall(() => _safe(() => _service.signIn(username, password)));

  @override
  Future<Result<void, Failure>> signOut() => makeApiCall(() => _safe(_service.signOut));

  Future<T> _safe<T>(Future<T> Function() request) async {
    try {
      return await request();
    } on DioException catch (error, stackTrace) {
      final failure = error.error;
      if (failure is AnistarFailure) {
        Error.throwWithStackTrace(failure, stackTrace);
      }
      rethrow;
    } on Failure {
      rethrow;
    } on Object catch (_, stackTrace) {
      // Neither a malformed response nor a plugin error may expose cookies or a POST body in logs.
      Error.throwWithStackTrace(
        const AnistarFailure(message: 'Не удалось выполнить вход. Повторите попытку.'),
        stackTrace,
      );
    }
  }
}
