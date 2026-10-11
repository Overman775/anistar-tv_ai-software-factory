import 'anistar_anime_summary_dto.dart';

final class AnistarCatalogPageDto {
  final bool hasNext;
  final List<AnistarAnimeSummaryDto> items;
  final int page;

  AnistarCatalogPageDto({required List<AnistarAnimeSummaryDto> items, required this.page, required this.hasNext})
    : items = List.unmodifiable(items);
}
