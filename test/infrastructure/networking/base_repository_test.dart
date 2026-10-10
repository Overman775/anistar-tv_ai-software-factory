import 'package:app_logging/app_logging.dart';
import 'package:core/data.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:networking/networking.dart';

void main() {
  final repository = BaseRepositoryTest();

  test('returns a success value when the request succeeds', () async {
    final result = await repository.call(() async => 7);

    expect(result.successOrNull, 7);
  });

  test('preserves an existing domain failure and wraps an unexpected error', () async {
    const domainFailure = UnknownFailure();
    final known = await repository.call<int>(() => throw domainFailure);
    expect(known.failureOrNull, same(domainFailure));
    final error = StateError('Malformed response');
    final unexpected = await repository.call<int>(() => throw error);
    final failure = unexpected.failureOrNull;
    expect(failure, isA<UnknownFailure>());
    expect(failure?.cause, same(error));
    expect(failure?.stackTrace, isNotNull);
  });

  test('a generic forbidden response does not acquire AniStar or playback policy', () async {
    final request = RequestOptions(path: '/resource');
    final result = await repository.call<int>(
      () => throw DioException(
        requestOptions: request,
        response: Response(statusCode: 403, requestOptions: request),
        type: DioExceptionType.badResponse,
      ),
    );
    expect(result.failureOrNull, isA<RequestFailure>());
    expect(result.failureOrNull?.message, 'Доступ к ресурсу запрещён.');
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
      result.when(failure: (failure) => failure, success: (_) => fail('Expected a mapped failure.')),
      isA<ServerFailure>(),
    );
  });

  test('preserves a user-facing detail returned by a server', () async {
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
    final failure = result.when(failure: (value) => value, success: (_) => fail('Expected a mapped failure.'));

    expect(failure, isA<RequestFailure>());
    expect(failure.message, 'Ссылка на серию устарела.');
    expect(failure.cause, same(error));
  });

  test('maps an empty bad request to a neutral request failure', () async {
    final requestOptions = RequestOptions(path: '/playback');
    final result = await repository.call<int>(
      () => throw DioException(
        requestOptions: requestOptions,
        response: Response(statusCode: 400, requestOptions: requestOptions),
        type: DioExceptionType.badResponse,
      ),
    );

    expect(
      result.when(failure: (failure) => failure.message, success: (_) => fail('Expected a mapped failure.')),
      'Сервер не принял параметры запроса.',
    );
  });
}

final class BaseRepositoryTest extends BaseRepository {
  BaseRepositoryTest() : super(Logger(level: Level.off));

  Future<Result<T, Failure>> call<T>(Future<T> Function() request) => makeApiCall(request);
}
