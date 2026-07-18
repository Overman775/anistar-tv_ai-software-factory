import 'package:anistar_api/anistar_api.dart';
import 'package:anistar_tv/packages/core/api/anistar_api_exception.dart';
import 'package:dio/dio.dart';

import '../../domain/models/anime_page.dart';
import '../../domain/models/anime_summary.dart';
import '../../domain/repositories/catalog_repository.dart';

final class AnistarCatalogRepository implements CatalogRepository {
  final AnimeApi _api;

  const AnistarCatalogRepository(this._api);

  @override
  Future<AnimePage> getPage(int page) async {
    try {
      final response = await _api.listAnime(page: page);
      final data = response.data;
      if (data == null) {
        throw const AnistarApiException(message: 'Parser вернул пустой каталог.');
      }

      return AnimePage(
        page: data.currentPage,
        hasNext: data.hasNext,
        items: (data.items ?? const <AnimeListItem>[])
            .map(
              (item) => AnimeSummary(
                id: item.id,
                slug: item.slug,
                title: item.title,
                year: item.year,
                posterUri: _networkUri(item.posterUrl),
              ),
            )
            .toList(growable: false),
      );
    } on DioException catch (error) {
      Error.throwWithStackTrace(AnistarApiException.fromDio(error), error.stackTrace);
    }
  }

  static Uri _networkUri(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri != null && uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https')) return uri;

    return Uri();
  }
}
