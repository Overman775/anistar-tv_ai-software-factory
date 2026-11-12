import 'anistar_anime_summary_dto.dart';

final class AnistarCatalogPageDto {
  final bool hasNext;
  final List<AnistarAnimeSummaryDto> items;
  final int page;
  final int? nextPageSize;

  AnistarCatalogPageDto({
    required List<AnistarAnimeSummaryDto> items,
    required this.page,
    required this.hasNext,
    this.nextPageSize,
  }) : items = List.unmodifiable(items);
}
