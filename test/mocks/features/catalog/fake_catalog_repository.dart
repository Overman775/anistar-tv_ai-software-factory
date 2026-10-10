import 'dart:async';

import 'package:anistar_tv/packages/features/catalog/domain/models/anime_page.dart';
import 'package:anistar_tv/packages/features/catalog/domain/models/anime_summary.dart';
import 'package:anistar_tv/packages/features/catalog/domain/repositories/catalog_repository.dart';
import 'package:core/data.dart';

final class FakeCatalogRepository implements CatalogRepository {
  @override
  Future<Result<AnimePage, Failure>> getPage(int page) async =>
      Result.success(_page(id: page, page: page, hasNext: page == 1));
}

final class ControlledCatalogRepository implements CatalogRepository {
  final Completer<AnimePage> pagination = Completer<AnimePage>();
  int _firstPageCalls = 0;

  @override
  Future<Result<AnimePage, Failure>> getPage(int page) {
    if (page == 2) {
      return pagination.future.then(Result.success);
    }
    _firstPageCalls++;

    return Future.value(Result.success(_page(id: _firstPageCalls == 1 ? 1 : 101, page: 1, hasNext: true)));
  }
}

AnimePage _page({required int id, required int page, required bool hasNext}) => AnimePage(
  items: [
    AnimeSummary(id: id, slug: '$id-anime', title: 'Аниме $id', posterUri: Uri.parse('https://images.test/$id.jpg')),
  ],
  page: page,
  hasNext: hasNext,
);
