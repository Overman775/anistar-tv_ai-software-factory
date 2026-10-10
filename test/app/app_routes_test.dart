import 'package:anistar_tv/app/app_routes.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('filter route preserves site-encoded genre bytes through query serialization', () {
    const path = '/filter/janrs/%EA%EE%EC%E5%E4%E8%FF/';
    const route = FilterRoute(path: path, title: 'Комедия');
    final uri = Uri.parse(route.location);

    expect(uri.path, '/browse');
    expect(uri.queryParameters, {'path': path, 'title': 'Комедия'});
  });

  test('player location carries the parameters required by its anime parent route', () {
    const route = PlayerRoute(animeId: 17, episodeNumber: 3, slug: '17-test-title', title: 'Тестовое аниме');

    final uri = Uri.parse(route.location);

    expect(uri.path, '/home/anime/player');
    expect(uri.queryParameters, {
      'anime-id': '17',
      'episode-number': '3',
      'slug': '17-test-title',
      'title': 'Тестовое аниме',
    });
  });
}
