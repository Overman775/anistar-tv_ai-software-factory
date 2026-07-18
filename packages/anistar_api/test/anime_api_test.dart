import 'package:test/test.dart';
import 'package:anistar_api/anistar_api.dart';

/// tests for AnimeApi
void main() {
  final instance = AnistarApi().getAnimeApi();

  group(AnimeApi, () {
    // Get anime details by slug
    //
    // Retrieve anime information by slug from list endpoint.
    //
    //Future<AnimeDetail> getAnimeDetail(String slug) async
    test('test getAnimeDetail', () async {
      // TODO
    });

    // Get anime list
    //
    // Retrieve a paginated list of anime from AniStar website.
    //
    //Future<PaginatedAnimeList> listAnime({ int page }) async
    test('test listAnime', () async {
      // TODO
    });

    // Get anime episodes
    //
    // Retrieve episode metadata and playback paths from the player page.
    //
    //Future<BuiltList<EpisodeInfo>> listAnimeEpisodes(int animeId) async
    test('test listAnimeEpisodes', () async {
      // TODO
    });
  });
}
