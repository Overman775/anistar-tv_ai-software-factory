import 'package:anistar_api/anistar_api.dart';
import 'package:anistar_tv/packages/features/catalog/data/repositories/anistar_catalog_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';

void main() {
  test('maps the generated paginated catalog contract to domain models', () async {
    final dio = Dio(BaseOptions(baseUrl: 'http://parser.test'));
    final adapter = DioAdapter(dio: dio);
    adapter.onGet(
      '/api/anime',
      (server) => server.reply(200, {
        'items': [
          {
            'id': 10921,
            'slug': '10921-test-anime',
            'title': 'Тестовое аниме',
            'year': '2026',
            'poster_url': 'https://images.test/poster.jpg',
          },
        ],
        'current_page': 1,
        'has_next': true,
        'has_prev': false,
      }),
      queryParameters: {'page': 1},
    );
    final repository = AnistarCatalogRepository(AnistarApi(dio: dio, interceptors: []).getAnimeApi());

    final page = await repository.getPage(1);
    final item = page.items.single;

    expect(page.page, 1);
    expect(page.hasNext, isTrue);
    expect(item.id, 10921);
    expect(item.slug, '10921-test-anime');
    expect(item.posterUri.host, 'images.test');
  });
}
