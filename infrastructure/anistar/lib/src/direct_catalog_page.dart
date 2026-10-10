import 'direct_anime.dart';

final class DirectCatalogPage {
  final bool hasNext;
  final List<DirectAnime> items;
  final int page;

  const DirectCatalogPage({required this.items, required this.page, required this.hasNext});
}
