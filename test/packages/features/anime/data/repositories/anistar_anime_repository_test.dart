import 'package:anistar/anistar.dart';
import 'package:anistar_tv/packages/features/anime/data/repositories/anistar_anime_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:networking/networking.dart';

import '../../../../../mocks/anistar/anistar_fixtures.dart';
import '../../../../../mocks/networking/html_fixture_adapter.dart';

void main() {
  test('detail and sorted episodes are fetched directly from HTML', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://v30.astar.bz/'))
      ..httpClientAdapter = HtmlFixtureAdapter({
        '/10938-test.html': detailHtml,
        '/test/player2/videoas_p2p_new.php': playerHtml,
      });
    addTearDown(() => dio.close(force: true));
    final repository = AnistarAnimeRepository(AnistarSource(dio));
    final data = (await repository.getAnime(
      id: 10938,
      slug: '10938-test',
    )).when(failure: (failure) => fail(failure.message), success: (value) => value);
    expect(data.details.genres, ['Приключения', 'Комедия']);
    expect(data.episodes.map((episode) => episode.number), [1, 2]);
    final missing = await repository.getAnime(id: 10938, slug: '10938-missing');
    expect(missing.when(failure: (failure) => failure, success: (_) => null), isA<RequestFailure>());
  });
}
