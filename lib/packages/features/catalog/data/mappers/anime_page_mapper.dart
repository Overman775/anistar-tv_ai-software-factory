import 'package:api/api.dart';

import '../../domain/models/anime_page.dart';
import '../../domain/models/anime_summary.dart';

extension AnimePageMapper on PaginatedAnimeListDto {
  AnimePage toDomain() => AnimePage(
    page: currentPage,
    hasNext: hasNext,
    items: (items ?? const <AnimeListItemDto>[]).map((item) => item.toDomain()).toList(growable: false),
  );
}

extension AnimeListItemDtoMapper on AnimeListItemDto {
  AnimeSummary toDomain() =>
      AnimeSummary(id: id, slug: slug, title: title, year: year, posterUri: Uri.tryParse(posterUrl.trim()) ?? Uri());
}
