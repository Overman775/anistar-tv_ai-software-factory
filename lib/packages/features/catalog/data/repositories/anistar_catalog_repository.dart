import 'package:api/api.dart';

import '../../../../core/core.dart';
import '../../domain/models/anime_page.dart';
import '../../domain/repositories/catalog_repository.dart';
import '../mappers/anime_page_mapper.dart';

final class AnistarCatalogRepository extends BaseRepository implements CatalogRepository {
  final AnimeClient _api;

  AnistarCatalogRepository(this._api, [super.logger]);

  @override
  Future<Either<Failure, AnimePage>> getPage(int page) =>
      makeApiCall(() async => (await _api.getApiAnime(page: page)).toDomain());
}
