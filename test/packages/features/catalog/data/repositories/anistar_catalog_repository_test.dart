import 'package:anistar/anistar.dart';
import 'package:anistar_tv/packages/features/catalog/data/repositories/anistar_catalog_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../../mocks/anistar/anistar_fixtures.dart';
import '../../../../../mocks/networking/html_fixture_adapter.dart';

void main() {
  test('catalog repository loads HTML without parser endpoints', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://v30.astar.bz/'));
    final adapter = HtmlFixtureAdapter({'/anime/': catalogHtml});
    dio.httpClientAdapter = adapter;
    final repository = AnistarCatalogRepository(AnistarSource(dio));
    final page = (await repository.getPage(1))
        .when(failure: (failure) => fail(failure.message), success: (page) => page);
    expect(page.items.single.id, 10938);
    expect(page.hasNext, isTrue);
    expect(adapter.requests.single.uri.path, '/anime/');
  });
}
