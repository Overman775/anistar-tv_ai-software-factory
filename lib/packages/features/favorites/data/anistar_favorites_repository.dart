import 'package:anistar/anistar.dart';
import 'package:core/data.dart';
import 'package:networking/networking.dart';

import '../../catalog/data/mapping/anistar_catalog_mapping.dart';
import '../../catalog/domain/models/anime_page.dart';
import '../../common/data/anistar_errors.dart';
import '../domain/favorites_repository.dart';

final class AnistarFavoritesRepository extends BaseRepository implements FavoritesRepository {
  final AnistarClient _client;

  AnistarFavoritesRepository(this._client, [super.logger]);

  @override
  Future<Result<AnimePage, Failure>> getPage(int page) => makeApiCall(
    () => mapAnistarErrors(() async {
      if (page < 1) {
        throw const RequestFailure(message: 'Некорректный номер страницы.');
      }
      final result = await _client.favorites(page);

      return mapCatalogPage(result, page, favoriteList: true);
    }),
  );

  @override
  Future<Result<bool, Failure>> getStatus({required int animeId, required String slug}) => makeApiCall(
    () => mapAnistarErrors(() async {
      if (animeId <= 0) {
        throw const RequestFailure(message: 'Некорректный номер аниме.');
      }

      return _client.favoriteStatus(animeId: animeId, slug: slug);
    }),
  );

  @override
  Future<Result<bool, Failure>> setFavorite({required int animeId, required String slug, required bool favorite}) =>
      makeApiCall(
        () => mapAnistarErrors(() async {
          if (animeId <= 0) {
            throw const RequestFailure(message: 'Некорректный номер аниме.');
          }

          return _client.setFavorite(animeId: animeId, slug: slug, favorite: favorite);
        }),
      );
}
