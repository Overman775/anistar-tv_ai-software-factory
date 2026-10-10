import 'package:dio/dio.dart';
import 'package:networking/networking.dart';

import 'anistar_failure.dart';
import 'anistar_favorites_html.dart';
import 'anistar_html_parser.dart';
import 'direct_anime.dart';
import 'direct_catalog_page.dart';
import 'direct_episode.dart';
import 'html_decoder.dart';

final class AnistarSource {
  final Uri baseUri;
  final Dio _dio;

  AnistarSource(this._dio) : baseUri = Uri.parse(_dio.options.baseUrl);

  Future<DirectCatalogPage> catalog(int page) async {
    if (page < 1) {
      throw const AnistarFailure(message: 'Некорректный номер страницы.');
    }
    final source = await _html(page == 1 ? 'anime/' : 'anime/page/$page/');

    return AnistarHtmlParser(baseUri).catalog(source, page);
  }

  Future<DirectAnime> details(String slug) async {
    if (!RegExp(r'^\d+-[^/?#]+$').hasMatch(slug)) {
      throw const AnistarFailure(message: 'Некорректный адрес аниме.');
    }
    final source = await _html('$slug.html');

    return AnistarHtmlParser(baseUri).details(source, slug);
  }

  Future<DirectCatalogPage> favorites(int page) async {
    if (page < 1) {
      throw const AnistarFailure(message: 'Некорректный номер страницы.');
    }
    final source = await _html('index.php?do=favorites&cstart=$page');

    return AnistarHtmlParser(baseUri).catalog(source, page, favorites: true);
  }

  Future<bool> favoriteStatus({required int animeId, required String slug}) async {
    final detail = await details(slug);
    final status = detail.isFavorite;
    if (detail.id != animeId || status == null) {
      throw const AnistarFailure(message: 'Не удалось определить избранное на сайте. Обновите страницу.');
    }

    return status;
  }

  Future<bool> setFavorite({required int animeId, required String slug, required bool favorite}) async {
    if (!RegExp(r'^\d+-[^/?#]+$').hasMatch(slug) || int.tryParse(slug.split('-').first) != animeId) {
      throw const AnistarFailure(message: 'Некорректный адрес аниме.');
    }
    final page = await _html('$slug.html');
    final current = AnistarFavoritesHtml.fragmentStatus(page, animeId);
    if (current == null) {
      throw const AnistarFailure(message: 'Не удалось определить избранное на сайте. Обновите страницу.');
    }
    if (current == favorite) {
      return current;
    }
    final response = await _dio.get<List<int>>(
      'engine/ajax/favorites.php',
      queryParameters: {
        'fav_id': animeId,
        'action': favorite ? 'plus' : 'minus',
        'skin': AnistarFavoritesHtml.skin(page),
        'alert': 0,
      },
      options: DioClient.withoutRetry(
        Options(
          responseType: ResponseType.bytes,
          headers: {
            'Accept': 'text/html',
            'User-Agent': 'AniStarTV/1.0',
            'Cache-Control': 'no-cache',
            'Referer': baseUri.resolve('$slug.html').toString(),
            'X-Requested-With': 'XMLHttpRequest',
          },
        ),
      ),
    );
    final fragment = HtmlDecoder.decode(response.data ?? const [], response.headers.value('content-type'));
    if (AnistarFavoritesHtml.fragmentStatus(fragment, animeId) != favorite) {
      throw const AnistarFailure(message: 'AniStar не подтвердил изменение избранного. Обновите статус.');
    }
    final confirmed = await favoriteStatus(animeId: animeId, slug: slug);
    if (confirmed != favorite) {
      throw const AnistarFailure(message: 'Избранное на сайте не изменилось. Повторите проверку.');
    }

    return confirmed;
  }

  Future<List<DirectEpisode>> episodes(int animeId) async {
    if (animeId <= 0) {
      throw const AnistarFailure(message: 'Некорректный номер аниме.');
    }
    final source = await _html('test/player2/videoas_p2p_new.php?id=$animeId');

    return AnistarHtmlParser(baseUri).episodes(source);
  }

  Uri playerUri(int animeId) => baseUri.resolve('test/player2/videoas_p2p_new.php?id=$animeId');

  Future<String> _html(String path) async {
    final Response<List<int>> response;
    try {
      response = await _dio.get<List<int>>(
        path,
        options: Options(
          responseType: ResponseType.bytes,
          headers: const {'Accept': 'text/html', 'User-Agent': 'AniStarTV/1.0', 'Cache-Control': 'no-cache'},
        ),
      );
    } on DioException catch (error, stackTrace) {
      final failure = error.error;
      if (failure is AnistarFailure) {
        Error.throwWithStackTrace(failure, stackTrace);
      }
      if (error.response?.statusCode != 403 && error.response?.headers.value('cf-mitigated') != 'challenge') {
        rethrow;
      }
      Error.throwWithStackTrace(
        const AnistarFailure(
          message: 'AniStar отклонил запрос или требует проверку браузера. Попробуйте другое зеркало.',
        ),
        stackTrace,
      );
    }
    if (response.headers.value('cf-mitigated') == 'challenge') {
      throw const AnistarFailure(message: 'AniStar запросил проверку браузера. Попробуйте другое зеркало.');
    }
    final data = response.data;
    if (data == null) {
      throw const AnistarFailure(message: 'AniStar вернул пустую страницу.');
    }

    return HtmlDecoder.decode(data, response.headers.value('content-type'));
  }
}
