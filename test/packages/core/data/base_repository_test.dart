import 'package:anistar_tv/packages/core/core.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';

void main() {
  final repository = BaseRepositoryTest();

  test('returns a right value when the request succeeds', () async {
    final result = await repository.call(() async => 7);

    expect(result.rightOrNull, 7);
  });

  test('maps an unavailable server to a server failure', () async {
    final result = await repository.call<int>(
      () => throw DioException(
        requestOptions: RequestOptions(path: '/catalog'),
        response: Response(statusCode: 503, requestOptions: RequestOptions(path: '/catalog')),
        type: DioExceptionType.badResponse,
      ),
    );

    expect(
      result.fold(onLeft: (failure) => failure, onRight: (_) => fail('Expected a mapped failure.')),
      isA<ServerFailure>(),
    );
  });

  test('preserves a user-facing detail returned by the parser', () async {
    final requestOptions = RequestOptions(path: '/playback');
    final error = DioException(
      requestOptions: requestOptions,
      response: Response(
        data: <String, Object?>{'detail': 'Ссылка на серию устарела.'},
        statusCode: 400,
        requestOptions: requestOptions,
      ),
      type: DioExceptionType.badResponse,
    );

    final result = await repository.call<int>(() => throw error);
    final failure = result.fold(onLeft: (value) => value, onRight: (_) => fail('Expected a mapped failure.'));

    expect(failure, isA<RequestFailure>());
    expect(failure.message, 'Ссылка на серию устарела.');
    expect(failure.cause, same(error));
  });

  test('maps an empty bad request to the playback session fallback', () async {
    final requestOptions = RequestOptions(path: '/playback');
    final result = await repository.call<int>(
      () => throw DioException(
        requestOptions: requestOptions,
        response: Response(statusCode: 400, requestOptions: requestOptions),
        type: DioExceptionType.badResponse,
      ),
    );

    expect(
      result.fold(onLeft: (failure) => failure.message, onRight: (_) => fail('Expected a mapped failure.')),
      'Сессия просмотра устарела. Запустите серию ещё раз.',
    );
  });
}

final class BaseRepositoryTest extends BaseRepository {
  BaseRepositoryTest() : super(Logger(level: Level.off));

  Future<Either<Failure, T>> call<T>(Future<T> Function() request) => makeApiCall(request);
}
