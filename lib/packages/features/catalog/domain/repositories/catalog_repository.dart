import '../models/anime_page.dart';

abstract interface class CatalogRepository {
  Future<AnimePage> getPage(int page);
}
