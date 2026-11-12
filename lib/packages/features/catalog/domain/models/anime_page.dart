import 'anime_summary.dart';

final class AnimePage {
  final bool hasNext;
  final List<AnimeSummary> items;
  final int page;
  final int? nextPageSize;

  AnimePage({required List<AnimeSummary> items, required this.page, required this.hasNext, this.nextPageSize})
    : items = List.unmodifiable(items);
}
