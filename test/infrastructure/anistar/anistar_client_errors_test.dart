import 'package:anistar/anistar.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../mocks/anistar/test_anistar_client.dart';

void main() {
  for (final (type, category) in [
    (DioExceptionType.connectionTimeout, AnistarClientErrorCategory.timeout),
    (DioExceptionType.receiveTimeout, AnistarClientErrorCategory.timeout),
    (DioExceptionType.connectionError, AnistarClientErrorCategory.connection),
    (DioExceptionType.badCertificate, AnistarClientErrorCategory.connection),
    (DioExceptionType.badResponse, AnistarClientErrorCategory.server),
  ]) {
    test('every network operation normalizes ${type.name} without leaking transport details', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://mirror.test/'));
      addTearDown(() => dio.close(force: true));
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (request, handler) {
            handler.reject(
              DioException(
                requestOptions: request,
                type: type,
                message: 'password=private Cookie=secret',
                response: Response(requestOptions: request, statusCode: 503, data: 'private response body'),
              ),
            );
          },
        ),
      );
      final client = createTestAnistarClient(dio);
      final operations = <Future<Object?> Function()>[
        () => client.catalog(1),
        client.genres,
        () => client.details('1-anime'),
        () => client.favorites(1),
        () => client.favoriteStatus(animeId: 1, slug: '1-anime'),
        () => client.setFavorite(animeId: 1, slug: '1-anime', favorite: true),
        () => client.episodes(1),
        () => client.watchedEpisodes(1),
        () => client.markWatched(animeId: 1, episodeNumber: 1),
        () => client.signIn('user', 'private'),
      ];
      for (final operation in operations) {
        await expectLater(
          operation(),
          throwsA(
            isA<AnistarClientException>()
                .having((error) => error.category, 'category', category)
                .having((error) => error.toString(), 'safe diagnostic', isNot(contains('private')))
                .having((error) => error.toString(), 'safe diagnostic', isNot(contains('secret'))),
          ),
        );
      }
    });
  }

  test('server response text never becomes a user message and requests retain status-specific advice', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://mirror.test/'));
    addTearDown(() => dio.close(force: true));
    var status = 400;
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (request, handler) => handler.reject(
          DioException(
            requestOptions: request,
            type: DioExceptionType.badResponse,
            response: Response(requestOptions: request, statusCode: status, data: {'detail': 'password=secret'}),
          ),
        ),
      ),
    );
    final client = createTestAnistarClient(dio);
    for (final (code, message) in [
      (400, 'Сервер не принял параметры запроса.'),
      (404, 'Запрошенные данные не найдены.'),
      (429, 'Слишком много запросов. Повторите позже.'),
    ]) {
      status = code;
      await expectLater(
        client.catalog(1),
        throwsA(
          isA<AnistarClientException>()
              .having((error) => error.category, 'category', AnistarClientErrorCategory.request)
              .having((error) => error.message, 'message', message),
        ),
      );
    }
  });
}
