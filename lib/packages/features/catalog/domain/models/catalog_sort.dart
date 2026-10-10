import 'catalog_sort_criterion.dart';

export 'catalog_sort_criterion.dart';

typedef CatalogSort = ({CatalogSortCriterion criterion, bool ascending});

const defaultCatalogSort = (criterion: CatalogSortCriterion.date, ascending: false);
