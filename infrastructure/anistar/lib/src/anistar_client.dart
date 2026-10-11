import 'direct_anime.dart';
import 'direct_catalog_filter.dart';
import 'direct_catalog_page.dart';
import 'direct_catalog_sort.dart';
import 'direct_episode.dart';

/// The application-wide data boundary for AniStar repositories.
///
/// Returns parsed site DTOs or throws; repositories map DTOs to domain models
/// and exceptions to Result/Failure. Transport, HTML and cookies stay behind
/// this contract. Riverpod supplies one client per active mirror/session.
abstract interface class AnistarClient {
  Stream<void> get expired;

  Future<String?> restore();
  Future<String> signIn(String username, String password);
  Future<void> signOut();

  Future<DirectCatalogPage> catalog(int page, {String? filterPath, DirectCatalogSort? sort});
  Future<List<DirectCatalogFilter>> genres();
  Future<DirectAnime> details(String slug);
  Future<DirectCatalogPage> favorites(int page);
  Future<bool> favoriteStatus({required int animeId, required String slug});
  Future<bool> setFavorite({required int animeId, required String slug, required bool favorite});
  Future<List<DirectEpisode>> episodes(int animeId);
  Uri playerUri(int animeId);
  Future<Set<int>> watchedEpisodes(int animeId);
  Future<Set<int>> markWatched({required int animeId, required int episodeNumber});
}
