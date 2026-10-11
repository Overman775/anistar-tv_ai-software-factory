import 'package:core/data.dart';

import '../models/anime_page.dart';
import '../models/catalog_filter.dart';
import '../models/catalog_sort.dart';
import 'catalog_browse_repository.dart';
import 'catalog_repository.dart';

final class FilteredCatalogRepository implements CatalogRepository {
  final CatalogBrowseRepository repository;
  final CatalogFilter filter;
  final CatalogSort sort;

  FilteredCatalogRepository(this.repository, this.filter, {this.sort = defaultCatalogSort});

  @override
  Future<Result<AnimePage, Failure>> getPage(int page) => repository.getFilteredPage(filter, page, sort: sort);
}
