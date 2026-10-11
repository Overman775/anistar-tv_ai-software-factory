import 'anime_summary.dart';

final class AnimePage {
  final bool hasNext;
  final List<AnimeSummary> items;
  final int page;

  AnimePage({required List<AnimeSummary> items, required this.page, required this.hasNext})
    : items = List.unmodifiable(items);
}
