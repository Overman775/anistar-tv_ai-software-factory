import 'package:core/data.dart';
import 'package:dio/dio.dart';

import 'anistar_auth_service.dart';
import 'anistar_client.dart';
import 'anistar_failure.dart';
import 'anistar_session.dart';
import 'anistar_source.dart';
import 'direct_anime.dart';
import 'direct_catalog_filter.dart';
import 'direct_catalog_page.dart';
import 'direct_catalog_sort.dart';
import 'direct_episode.dart';

/// Coordinates parsed data and authentication using the same Dio and session.
/// Dependencies are supplied by the composition root, never resolved here.
final class DioAnistarClient implements AnistarClient {
  final AnistarSource _source;
  final AnistarAuthService _auth;

  @override
  Stream<void> get expired => _auth.session.expired;

  DioAnistarClient(Dio dio, AnistarSession session, {Future<void> Function()? ensureMirror})
    : _source = AnistarSource(dio),
      _auth = AnistarAuthService(dio, session, ensureMirror: ensureMirror);

  @override
  Future<String?> restore({void Function()? onSessionCheck}) =>
      _safeAuth(() => _auth.restore(onSessionCheck: onSessionCheck));

  @override
  Future<String> signIn(String username, String password) => _safeAuth(() => _auth.signIn(username, password));

  @override
  Future<void> signOut() => _safeAuth(_auth.signOut);

  @override
  Future<DirectCatalogPage> catalog(int page, {String? filterPath, DirectCatalogSort? sort}) =>
      _source.catalog(page, filterPath: filterPath, sort: sort);

  @override
  Future<List<DirectCatalogFilter>> genres() => _source.genres();

  @override
  Future<DirectAnime> details(String slug) => _source.details(slug);

  @override
  Future<DirectCatalogPage> favorites(int page) => _source.favorites(page);

  @override
  Future<bool> favoriteStatus({required int animeId, required String slug}) =>
      _source.favoriteStatus(animeId: animeId, slug: slug);

  @override
  Future<bool> setFavorite({required int animeId, required String slug, required bool favorite}) =>
      _source.setFavorite(animeId: animeId, slug: slug, favorite: favorite);

  @override
  Future<List<DirectEpisode>> episodes(int animeId) => _source.episodes(animeId);

  @override
  Uri playerUri(int animeId) => _source.playerUri(animeId);

  @override
  Future<Set<int>> watchedEpisodes(int animeId) => _source.watchedEpisodes(animeId);

  @override
  Future<Set<int>> markWatched({required int animeId, required int episodeNumber}) =>
      _source.markWatched(animeId: animeId, episodeNumber: episodeNumber);

  Future<T> _safeAuth<T>(Future<T> Function() request) async {
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
      // Plugin/parser errors must not expose cookies or submitted credentials.
      Error.throwWithStackTrace(
        const AnistarFailure(message: 'Не удалось выполнить вход. Повторите попытку.'),
        stackTrace,
      );
    }
  }
}
