import 'package:anistar/anistar.dart';
import 'package:core/data.dart';
import 'package:networking/networking.dart';

import '../../../common/data/anistar_errors.dart';
import '../../domain/models/anime_page.dart';
import '../../domain/models/catalog_filter.dart';
import '../../domain/models/catalog_sort.dart';
import '../../domain/repositories/catalog_browse_repository.dart';
import '../../domain/repositories/catalog_repository.dart';
import '../mapping/anistar_catalog_mapping.dart';

final class AnistarCatalogRepository extends BaseRepository implements CatalogRepository, CatalogBrowseRepository {
  final AnistarClient _client;

  AnistarCatalogRepository(this._client, [super.logger]);

  @override
  Future<Result<List<CatalogFilter>, Failure>> getGenres() => makeApiCall(
    () => mapAnistarErrors(() async => List.unmodifiable((await _client.genres()).map(mapCatalogFilter))),
  );

  @override
  Future<Result<AnimePage, Failure>> getFilteredPage(
    CatalogFilter filter,
    int page, {
    CatalogSort sort = defaultCatalogSort,
  }) => _page(page, filter.path, sort: sort);

  @override
  Future<Result<AnimePage, Failure>> getPage(int page) => _page(page, null);

  Future<Result<AnimePage, Failure>> _page(int page, String? path, {CatalogSort? sort}) => makeApiCall(
    () => mapAnistarErrors(() async {
      if (page < 1) {
        throw const RequestFailure(message: 'Некорректный номер страницы.');
      }
      final result = await _client.catalog(
        page,
        filterPath: path,
        sort: sort == null
            ? null
            : AnistarCatalogSort(switch (sort.criterion) {
                CatalogSortCriterion.date => AnistarSortCriterion.date,
                CatalogSortCriterion.popularity => AnistarSortCriterion.rating,
                CatalogSortCriterion.visits => AnistarSortCriterion.views,
                CatalogSortCriterion.comments => AnistarSortCriterion.comments,
                CatalogSortCriterion.title => AnistarSortCriterion.title,
              }, ascending: sort.ascending),
      );

      return mapCatalogPage(result, page);
    }),
  );
}
