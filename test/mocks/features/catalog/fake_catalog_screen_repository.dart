import 'package:anistar_tv/packages/features/catalog/domain/models/anime_page.dart';
import 'package:anistar_tv/packages/features/catalog/domain/models/anime_summary.dart';
import 'package:anistar_tv/packages/features/catalog/domain/repositories/catalog_repository.dart';
import 'package:core/data.dart';

final class FakeCatalogScreenRepository implements CatalogRepository {
  final Future<Result<AnimePage, Failure>> Function(int)? load;

  const FakeCatalogScreenRepository({this.load});

  @override
  Future<Result<AnimePage, Failure>> getPage(int page) async {
    final loader = load;
    if (loader != null) {
      return loader(page);
    }

    return Result.success(
      AnimePage(
        items: List.generate(
          12,
          (index) =>
              AnimeSummary(id: index + 1, slug: '${index + 1}-anime', title: 'Аниме ${index + 1}', posterUri: Uri()),
          growable: false,
        ),
        page: 1,
        hasNext: false,
      ),
    );
  }
}
