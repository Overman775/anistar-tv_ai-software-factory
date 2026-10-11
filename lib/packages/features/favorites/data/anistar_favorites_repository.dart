import 'package:anistar/anistar.dart';
import 'package:core/data.dart';
import 'package:networking/networking.dart';

import '../../catalog/domain/models/anime_page.dart';
import '../../catalog/domain/models/anime_summary.dart';
import '../domain/favorites_repository.dart';

final class AnistarFavoritesRepository extends BaseRepository implements FavoritesRepository {
  final AnistarClient _client;

  AnistarFavoritesRepository(this._client, [super.logger]);

  @override
  Future<Result<AnimePage, Failure>> getPage(int page) => makeApiCall(() async {
    final result = await _client.favorites(page);

    return AnimePage(
      page: result.page,
      hasNext: result.hasNext,
      items: result.items
          .map(
            (item) => AnimeSummary(
              id: item.id,
              slug: item.slug,
              title: item.title,
              posterUri: item.posterUri ?? Uri(),
              year: item.year,
              isFavorite: true,
            ),
          )
          .toList(growable: false),
    );
  });

  @override
  Future<Result<bool, Failure>> getStatus({required int animeId, required String slug}) =>
      makeApiCall(() => _client.favoriteStatus(animeId: animeId, slug: slug));

  @override
  Future<Result<bool, Failure>> setFavorite({required int animeId, required String slug, required bool favorite}) =>
      makeApiCall(() => _client.setFavorite(animeId: animeId, slug: slug, favorite: favorite));
}
