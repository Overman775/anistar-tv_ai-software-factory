// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import '../models/anime_detail_dto.dart';
import '../models/episode_info_dto.dart';
import '../models/paginated_anime_list_dto.dart';

part 'anime_client.g.dart';

@RestApi()
abstract class AnimeClient {
  factory AnimeClient(Dio dio, {String? baseUrl}) = _AnimeClient;

  /// Get anime list.
  ///
  /// Retrieve a paginated list of anime from AniStar website.
  ///
  /// [page] - Page number (/page/{n}).
  @GET('/api/anime')
  Future<PaginatedAnimeListDto> getApiAnime({@Query('page') int? page = 1});

  /// Get anime episodes.
  ///
  /// Retrieve episode metadata and playback paths from the player page.
  @GET('/api/anime/{anime_id}/episodes')
  Future<List<EpisodeInfoDto>> getApiAnimeAnimeIdEpisodes({
    @Path('anime_id') required int animeId,
  });

  /// Get anime details by slug.
  ///
  /// Retrieve anime information by slug from list endpoint.
  @GET('/api/anime/{slug}')
  Future<AnimeDetailDto> getApiAnimeSlug({@Path('slug') required String slug});
}
