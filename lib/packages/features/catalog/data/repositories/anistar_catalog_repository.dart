import 'package:anistar/anistar.dart';
import 'package:core/data.dart';
import 'package:networking/networking.dart';

import '../../domain/models/anime_page.dart';
import '../../domain/models/anime_summary.dart';
import '../../domain/repositories/catalog_repository.dart';

final class AnistarCatalogRepository extends BaseRepository implements CatalogRepository {
  final AnistarSource _source;

  AnistarCatalogRepository(this._source, [super.logger]);

  @override
  Future<Result<AnimePage, Failure>> getPage(int page) => makeApiCall(() async {
    final result = await _source.catalog(page);

    return AnimePage(
      page: result.page,
      hasNext: result.hasNext,
      items: result.items
          .map(
            (item) => AnimeSummary(
              id: item.id,
              isFavorite: item.isFavorite,
              slug: item.slug,
              title: item.title,
              posterUri: item.posterUri ?? Uri(),
              year: item.year,
            ),
          )
          .toList(growable: false),
    );
  });
}
