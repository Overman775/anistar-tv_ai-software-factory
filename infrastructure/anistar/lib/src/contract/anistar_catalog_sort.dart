final class AnistarCatalogSort {
  final AnistarSortCriterion criterion;
  final bool ascending;

  const AnistarCatalogSort(this.criterion, {this.ascending = false});
}

enum AnistarSortCriterion { date, rating, views, comments, title }
