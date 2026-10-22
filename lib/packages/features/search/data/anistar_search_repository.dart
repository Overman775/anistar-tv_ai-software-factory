import 'package:anistar/anistar.dart';
import 'package:core/data.dart';
import 'package:networking/networking.dart';

import '../../catalog/data/mapping/anistar_catalog_mapping.dart';
import '../../catalog/domain/models/anime_page.dart';
import '../../common/data/anistar_errors.dart';
import '../domain/search_repository.dart';

final class AnistarSearchRepository extends BaseRepository implements SearchRepository {
  final AnistarClient _client;

  AnistarSearchRepository(this._client, [super.logger]);

  @override
  Future<Result<AnimePage, Failure>> search(String query, {int page = 1, RequestCancellation? cancellation}) =>
      makeApiCall(
        () => mapAnistarErrors(() async {
          final response = await _client.search(query, page: page, cancellation: cancellation);

          return mapCatalogPage(response, page);
        }),
      );
}
