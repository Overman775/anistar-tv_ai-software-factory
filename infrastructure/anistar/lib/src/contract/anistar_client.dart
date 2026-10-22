import 'package:core/data.dart';

import 'anistar_anime_details_dto.dart';
import 'anistar_catalog_filter_dto.dart';
import 'anistar_catalog_page_dto.dart';
import 'anistar_catalog_sort.dart';
import 'anistar_episode_dto.dart';

/// The application-wide data boundary for AniStar repositories.
///
/// Returns normalized immutable DTOs or throws AnistarClientException for expected failures; repositories map DTOs to domain models
/// and exceptions to Result/Failure. Transport, HTML and cookies stay behind
/// this contract. Implementations preserve ID/slug/filter paths/pages and supported operations.
/// Null on restore means no valid account and is a successful result.
/// Unexpected programming failures are distinct from expected client exceptions.
abstract interface class AnistarClient {
  Stream<void> get expired;

  Future<String?> restore({void Function()? onSessionCheck});
  Future<String> signIn(String username, String password, {RequestCancellation? cancellation});
  Future<void> cancelSignIn(RequestCancellation cancellation);
  Future<void> signOut();

  Future<AnistarCatalogPageDto> catalog(int page, {String? filterPath, AnistarCatalogSort? sort});
  Future<AnistarCatalogPageDto> search(String query, {int page = 1, RequestCancellation? cancellation});
  Future<List<AnistarCatalogFilterDto>> genres();
  Future<AnistarAnimeDetailsDto> details(String slug);
  Future<AnistarCatalogPageDto> favorites(int page);
  Future<bool> favoriteStatus({required int animeId, required String slug});
  Future<bool> setFavorite({required int animeId, required String slug, required bool favorite});
  Future<List<AnistarEpisodeDto>> episodes(int animeId);
  Future<Set<int>> watchedEpisodes(int animeId);
  Future<Set<int>> markWatched({required int animeId, required int episodeNumber});
}
