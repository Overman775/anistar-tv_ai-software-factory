import 'package:core/data.dart';
import 'package:dio/dio.dart';

import 'anistar_auth_service.dart';
import 'anistar_failure.dart';
import 'anistar_session.dart';
import 'anistar_source.dart';
import 'contract/anistar_anime_details_dto.dart';
import 'contract/anistar_catalog_filter_dto.dart';
import 'contract/anistar_catalog_page_dto.dart';
import 'contract/anistar_catalog_sort.dart';
import 'contract/anistar_client.dart';
import 'contract/anistar_client_exception.dart';
import 'contract/anistar_episode_dto.dart';

/// Coordinates parsed data and authentication using the same Dio and session.
/// Dependencies are supplied by the composition root, never resolved here.
final class HtmlAnistarClient implements AnistarClient {
  final AnistarSource _source;
  final AnistarAuthService _auth;

  @override
  Stream<void> get expired => _auth.session.expired;

  HtmlAnistarClient(Dio dio, AnistarSession session, {Future<void> Function()? ensureMirror})
    : _source = AnistarSource(dio),
      _auth = AnistarAuthService(dio, session, ensureMirror: ensureMirror);

  @override
  Future<String?> restore({void Function()? onSessionCheck}) =>
      _safe(() => _auth.restore(onSessionCheck: onSessionCheck));

  @override
  Future<String> signIn(String username, String password) => _safe(() => _auth.signIn(username, password));

  @override
  Future<void> signOut() => _safe(_auth.signOut);

  @override
  Future<AnistarCatalogPageDto> catalog(int page, {String? filterPath, AnistarCatalogSort? sort}) =>
      _safe(() => _source.catalog(page, filterPath: filterPath, sort: sort));

  @override
  Future<List<AnistarCatalogFilterDto>> genres() => _safe(_source.genres);

  @override
  Future<AnistarAnimeDetailsDto> details(String slug) => _safe(() => _source.details(slug));

  @override
  Future<AnistarCatalogPageDto> favorites(int page) => _safe(() => _source.favorites(page));

  @override
  Future<bool> favoriteStatus({required int animeId, required String slug}) =>
      _safe(() => _source.favoriteStatus(animeId: animeId, slug: slug));

  @override
  Future<bool> setFavorite({required int animeId, required String slug, required bool favorite}) =>
      _safe(() => _source.setFavorite(animeId: animeId, slug: slug, favorite: favorite));

  @override
  Future<List<AnistarEpisodeDto>> episodes(int animeId) => _safe(() => _source.episodes(animeId));

  @override
  Future<Set<int>> watchedEpisodes(int animeId) => _safe(() => _source.watchedEpisodes(animeId));

  @override
  Future<Set<int>> markWatched({required int animeId, required int episodeNumber}) =>
      _safe(() => _source.markWatched(animeId: animeId, episodeNumber: episodeNumber));

  Future<T> _safe<T>(Future<T> Function() request) async {
    try {
      return await request();
    } on DioException catch (error, stackTrace) {
      final embedded = error.error;
      if (embedded is AnistarFailure) {
        Error.throwWithStackTrace(
          AnistarClientException(AnistarClientErrorCategory.request, embedded.message),
          stackTrace,
        );
      }
      final category = switch (error.type) {
        DioExceptionType.connectionTimeout ||
        DioExceptionType.sendTimeout ||
        DioExceptionType.receiveTimeout ||
        DioExceptionType.transformTimeout => AnistarClientErrorCategory.timeout,
        DioExceptionType.connectionError ||
        DioExceptionType.cancel ||
        DioExceptionType.badCertificate => AnistarClientErrorCategory.connection,
        DioExceptionType.badResponse =>
          (error.response?.statusCode ?? 0) >= 500 && (error.response?.statusCode ?? 0) <= 599
              ? AnistarClientErrorCategory.server
              : AnistarClientErrorCategory.request,
        DioExceptionType.unknown => null,
      };
      if (category == null) {
        Error.throwWithStackTrace(StateError('Unexpected AniStar transport failure'), stackTrace);
      }
      final message = switch (category) {
        AnistarClientErrorCategory.timeout => 'Превышено время ожидания ответа сервера.',
        AnistarClientErrorCategory.connection => 'Не удалось подключиться к серверу.',
        AnistarClientErrorCategory.server => 'Сервер временно недоступен.',
        AnistarClientErrorCategory.invalidCredentials => 'Вход не выполнен. Проверьте логин и пароль.',
        AnistarClientErrorCategory.request => switch (error.response?.statusCode) {
          403 => 'AniStar отклонил запрос или требует проверку браузера. Попробуйте другое зеркало.',
          400 || 422 => 'Сервер не принял параметры запроса.',
          404 => 'Запрошенные данные не найдены.',
          429 => 'Слишком много запросов. Повторите позже.',
          _ => 'Сервер отклонил запрос.',
        },
      };
      Error.throwWithStackTrace(AnistarClientException(category, message), stackTrace);
    } on AnistarFailure catch (failure, stackTrace) {
      Error.throwWithStackTrace(
        AnistarClientException(AnistarClientErrorCategory.request, failure.message),
        stackTrace,
      );
    } on AnistarClientException {
      rethrow;
    } on Failure catch (failure, stackTrace) {
      Error.throwWithStackTrace(
        AnistarClientException(AnistarClientErrorCategory.request, failure.message),
        stackTrace,
      );
    } on Object catch (_, stackTrace) {
      // Keep unexpected failures distinct without leaking plugin/credential text.
      Error.throwWithStackTrace(StateError('Unexpected AniStar client failure'), stackTrace);
    }
  }
}
