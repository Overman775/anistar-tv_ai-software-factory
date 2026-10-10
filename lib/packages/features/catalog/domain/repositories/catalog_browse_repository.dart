import 'package:core/data.dart';

import '../models/anime_page.dart';
import '../models/catalog_filter.dart';
import '../models/catalog_sort.dart';

abstract interface class CatalogBrowseRepository {
  Future<Result<List<CatalogFilter>, Failure>> getGenres();
  Future<Result<AnimePage, Failure>> getFilteredPage(
    CatalogFilter filter,
    int page, {
    CatalogSort sort = defaultCatalogSort,
  });
}
