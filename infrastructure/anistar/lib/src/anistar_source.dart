import 'package:dio/dio.dart';
import 'package:networking/networking.dart';

import 'anistar_failure.dart';
import 'anistar_favorites_html.dart';
import 'anistar_html_parser.dart';
import 'contract/anistar_anime_details_dto.dart';
import 'contract/anistar_catalog_filter_dto.dart';
import 'contract/anistar_catalog_page_dto.dart';
import 'contract/anistar_catalog_sort.dart';
import 'contract/anistar_episode_dto.dart';
import 'html_catalog_parameters.dart';
import 'html_decoder.dart';
import 'parsed_episode.dart';

final class AnistarSource {
  final Uri baseUri;
  final Dio _dio;

  AnistarSource(this._dio) : baseUri = Uri.parse(_dio.options.baseUrl);

  Future<AnistarCatalogPageDto> catalog(int page, {String? filterPath, AnistarCatalogSort? sort}) async {
    if (page < 1) {
      throw const AnistarFailure(message: 'Некорректный номер страницы.');
    }
    if (filterPath != null && !HtmlCatalogParameters.isValidPath(filterPath)) {
      throw const AnistarFailure(message: 'Некорректный адрес фильтра.');
    }
    final parameters = sort == null ? null : HtmlCatalogParameters(sort);
    final path = (filterPath ?? '/anime/').substring(1);
    final source = await _html(
      page == 1 ? path : '${path}page/$page/',
      sortCookies: parameters?.cookies(filterPath ?? '/anime/'),
    );
    parameters?.verify(source);

    return AnistarHtmlParser(baseUri).catalog(source, page, filterPath: filterPath);
  }

  Future<List<AnistarCatalogFilterDto>> genres() async => AnistarHtmlParser(baseUri).genres(await _html('anime/'));

  Future<AnistarAnimeDetailsDto> details(String slug) async {
    if (!RegExp(r'^\d+-[^/?#]*$').hasMatch(slug)) {
      throw const AnistarFailure(message: 'Некорректный адрес аниме.');
    }
    final source = await _html('$slug.html');

    return AnistarHtmlParser(baseUri).details(source, slug);
  }

  Future<AnistarCatalogPageDto> favorites(int page) async {
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
    if (!RegExp(r'^\d+-[^/?#]*$').hasMatch(slug) || int.tryParse(slug.split('-').first) != animeId) {
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

  Future<List<AnistarEpisodeDto>> episodes(int animeId) async =>
      List.unmodifiable((await _playlist(animeId)).map((item) => item.episode));

  Uri playerUri(int animeId) => baseUri.resolve('test/player2/videoas_p2p_new.php?id=$animeId');

  Future<Set<int>> watchedEpisodes(int animeId) async => Set.unmodifiable(
    (await episodes(animeId)).where((episode) => episode.isWatched).map((episode) => episode.number),
  );

  Future<Set<int>> markWatched({required int animeId, required int episodeNumber}) async {
    final playlist = await _playlist(animeId);
    final matches = playlist.where((item) => item.episode.number == episodeNumber);
    if (matches.isEmpty) {
      throw const AnistarFailure(message: 'Не удалось найти серию для отметки просмотра.');
    }
    final episode = matches.first;
    if (episode.episode.isWatched) {
      return Set.unmodifiable(playlist.where((item) => item.episode.isWatched).map((item) => item.episode.number));
    }
    final mediaId = episode.mediaId;
    if (mediaId == null) {
      throw const AnistarFailure(message: 'AniStar не выдал идентификатор просмотра серии.');
    }
    await _dio.get<List<int>>(
      'engine/ajax/ns.php',
      queryParameters: {'vid': mediaId},
      options: DioClient.withoutRetry(
        Options(
          responseType: ResponseType.bytes,
          headers: {
            'Referer': playerUri(animeId).toString(),
            'Cache-Control': 'no-cache',
            'User-Agent': 'AniStarTV/1.0',
          },
        ),
      ),
    );
    final confirmed = await watchedEpisodes(animeId);
    if (!confirmed.contains(episodeNumber)) {
      throw const AnistarFailure(message: 'AniStar не подтвердил отметку просмотра.');
    }

    return confirmed;
  }

  Future<List<ParsedEpisode>> _playlist(int animeId) async {
    if (animeId <= 0) {
      throw const AnistarFailure(message: 'Некорректный номер аниме.');
    }
    final source = await _html('test/player2/videoas_p2p_new.php?id=$animeId');

    return AnistarHtmlParser(baseUri).parsedEpisodes(source, httpHeaders: {'Referer': playerUri(animeId).toString()});
  }

  Future<String> _html(String path, {Map<String, String>? sortCookies}) async {
    final Response<List<int>> response;
    try {
      response = await _dio.get<List<int>>(
        path,
        options: Options(
          responseType: ResponseType.bytes,
          extra: {'anistarSortCookies': ?sortCookies},
          headers: {
            'Accept': 'text/html',
            'User-Agent': 'AniStarTV/1.0',
            'Cache-Control': 'no-cache',
            if (sortCookies != null)
              'Cookie': sortCookies.entries.map((entry) => '${entry.key}=${entry.value}').join('; '),
          },
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
