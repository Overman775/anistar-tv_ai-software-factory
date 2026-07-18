import 'package:anistar_tv/packages/features/catalog/domain/models/anime_page.dart';
import 'package:anistar_tv/packages/features/catalog/domain/models/anime_summary.dart';
import 'package:anistar_tv/packages/features/catalog/domain/repositories/catalog_repository.dart';

final class FakeCatalogRepository implements CatalogRepository {
  @override
  Future<AnimePage> getPage(int page) async {
    final item = AnimeSummary(
      id: page,
      slug: '$page-anime',
      title: 'Аниме $page',
      posterUri: Uri.parse('https://images.test/$page.jpg'),
    );

    return AnimePage(items: [item], page: page, hasNext: page == 1);
  }
}
