import 'package:anistar/anistar.dart';
import 'package:core/data.dart';
import 'package:networking/networking.dart';

import '../../domain/models/anime_page.dart';
import '../../domain/models/anime_summary.dart';
import '../../domain/models/catalog_filter.dart';
import '../../domain/models/catalog_sort.dart';
import '../../domain/repositories/catalog_browse_repository.dart';
import '../../domain/repositories/catalog_repository.dart';

final class AnistarCatalogRepository extends BaseRepository implements CatalogRepository, CatalogBrowseRepository {
  final AnistarClient _client;

  AnistarCatalogRepository(this._client, [super.logger]);

  @override
  Future<Result<List<CatalogFilter>, Failure>> getGenres() => makeApiCall(
    () async => (await _client.genres())
        .map((item) => CatalogFilter(label: item.label, path: item.path))
        .toList(growable: false),
  );

  @override
  Future<Result<AnimePage, Failure>> getFilteredPage(
    CatalogFilter filter,
    int page, {
    CatalogSort sort = defaultCatalogSort,
  }) => _page(page, filter.path, sort: sort);

  @override
  Future<Result<AnimePage, Failure>> getPage(int page) => _page(page, null);

  Future<Result<AnimePage, Failure>> _page(int page, String? path, {CatalogSort? sort}) => makeApiCall(() async {
    final result = await _client.catalog(
      page,
      filterPath: path,
      sort: sort == null
          ? null
          : DirectCatalogSort(switch (sort.criterion) {
              CatalogSortCriterion.date => DirectSortCriterion.date,
              CatalogSortCriterion.popularity => DirectSortCriterion.rating,
              CatalogSortCriterion.visits => DirectSortCriterion.newsRead,
              CatalogSortCriterion.comments => DirectSortCriterion.comments,
              CatalogSortCriterion.title => DirectSortCriterion.title,
            }, ascending: sort.ascending),
    );

    return AnimePage(
      page: result.page,
      hasNext: result.hasNext,
      items: result.items
          .map(
            (item) => AnimeSummary(
              id: item.id,
              isFavorite: item.isFavorite,
              slug: item.slug,
              title: item.title,
              posterUri: item.posterUri ?? Uri(),
              year: item.year,
            ),
          )
          .toList(growable: false),
    );
  });
}
