import 'package:anistar_tv/packages/features/catalog/domain/models/anime_page.dart';
import 'package:anistar_tv/packages/features/catalog/domain/models/catalog_filter.dart';
import 'package:anistar_tv/packages/features/catalog/domain/models/catalog_sort.dart';
import 'package:anistar_tv/packages/features/catalog/domain/repositories/catalog_browse_repository.dart';
import 'package:core/data.dart';

const comedyFilter = CatalogFilter(label: 'Комедия', path: '/anime/comedy/');
const ongoingFilter = CatalogFilter(label: 'Онгоинги', path: '/new/');

class FakeCatalogBrowseRepository implements CatalogBrowseRepository {
  final Future<Result<AnimePage, Failure>> Function(CatalogFilter, int)? load;
  final Future<Result<List<CatalogFilter>, Failure>> Function()? genres;
  final sorts = <CatalogSort>[];
  final requests = <(String, int)>[];

  FakeCatalogBrowseRepository({this.load, this.genres});

  @override
  Future<Result<List<CatalogFilter>, Failure>> getGenres() =>
      genres?.call() ?? Future.value(const Result.success([comedyFilter, ongoingFilter]));

  @override
  Future<Result<AnimePage, Failure>> getFilteredPage(
    CatalogFilter filter,
    int page, {
    CatalogSort sort = defaultCatalogSort,
  }) {
    requests.add((filter.path, page));
    sorts.add(sort);

    return load?.call(filter, page) ??
        Future.value(Result.success(AnimePage(page: page, hasNext: false, items: const [])));
  }
}
