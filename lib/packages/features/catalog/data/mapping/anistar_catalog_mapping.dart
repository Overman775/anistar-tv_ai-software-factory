import 'package:anistar/anistar.dart';
import 'package:networking/networking.dart';

import '../../domain/models/anime_page.dart';
import '../../domain/models/anime_summary.dart';
import '../../domain/models/catalog_filter.dart';

CatalogFilter mapCatalogFilter(AnistarCatalogFilterDto item) =>
    CatalogFilter(label: item.label, path: item.path, imageUri: item.imageUri);

AnimeSummary mapAnimeSummary(AnistarAnimeSummaryDto item, {bool favoriteList = false}) {
  if (item.id <= 0 || item.slug.isEmpty || item.title.trim().isEmpty) {
    throw const RequestFailure(message: 'Некорректные данные аниме.');
  }
  final rating = item.rating;

  return AnimeSummary.withGenreFilters(
    id: item.id,
    slug: item.slug,
    title: item.title,
    posterUri: item.posterUri,
    year: item.year,
    rating: rating != null && rating.isFinite && rating >= 0 && rating <= 10 ? rating : null,
    isFavorite: favoriteList ? true : item.isFavorite,
    genreText: item.genreText,
    genreFilters: item.genreFilters.map(mapCatalogFilter).toList(growable: false),
    seriesInfo: item.seriesInfo,
    voiceover: item.voiceover,
    description: item.description,
    updateMessage: item.updateMessage,
    publicationDate: item.publicationDate,
  );
}

AnimePage mapCatalogPage(AnistarCatalogPageDto result, int page, {bool favoriteList = false}) {
  if (result.page != page) {
    throw const RequestFailure(message: 'Номер страницы ответа не соответствует запросу.');
  }

  return AnimePage(
    page: result.page,
    hasNext: result.hasNext,
    nextPageSize: result.nextPageSize,
    items: result.items.map((item) => mapAnimeSummary(item, favoriteList: favoriteList)).toList(),
  );
}
