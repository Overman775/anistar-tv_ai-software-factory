import 'anime_summary.dart';

final class AnimePage {
  final bool hasNext;
  final List<AnimeSummary> items;
  final int page;

  const AnimePage({required this.items, required this.page, required this.hasNext});
}
