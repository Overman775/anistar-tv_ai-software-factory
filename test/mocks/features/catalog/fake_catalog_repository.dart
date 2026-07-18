import 'dart:async';

import 'package:anistar_tv/packages/core/core.dart';
import 'package:anistar_tv/packages/features/catalog/domain/models/anime_page.dart';
import 'package:anistar_tv/packages/features/catalog/domain/models/anime_summary.dart';
import 'package:anistar_tv/packages/features/catalog/domain/repositories/catalog_repository.dart';

final class FakeCatalogRepository implements CatalogRepository {
  @override
  Future<Either<Failure, AnimePage>> getPage(int page) async =>
      Either.right(_page(id: page, page: page, hasNext: page == 1));
}

final class ControlledCatalogRepository implements CatalogRepository {
  final Completer<AnimePage> pagination = Completer<AnimePage>();
  int _firstPageCalls = 0;

  @override
  Future<Either<Failure, AnimePage>> getPage(int page) {
    if (page == 2) return pagination.future.then(Either.right);
    _firstPageCalls++;

    return Future.value(Either.right(_page(id: _firstPageCalls == 1 ? 1 : 101, page: 1, hasNext: true)));
  }
}

AnimePage _page({required int id, required int page, required bool hasNext}) => AnimePage(
  items: [
    AnimeSummary(id: id, slug: '$id-anime', title: 'Аниме $id', posterUri: Uri.parse('https://images.test/$id.jpg')),
  ],
  page: page,
  hasNext: hasNext,
);
