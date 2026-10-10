import 'package:core/data.dart';

import '../../catalog/domain/repositories/catalog_repository.dart';

abstract interface class FavoritesRepository implements CatalogRepository {
  Future<Result<bool, Failure>> getStatus({required int animeId, required String slug});
  Future<Result<bool, Failure>> setFavorite({required int animeId, required String slug, required bool favorite});
}
