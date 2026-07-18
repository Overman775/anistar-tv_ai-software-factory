// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import '../models/playback_info_dto.dart';
import '../models/quality_type_dto.dart';

part 'video_client.g.dart';

@RestApi()
abstract class VideoClient {
  factory VideoClient(Dio dio, {String? baseUrl}) = _VideoClient;

  /// Get HLS playback information.
  ///
  /// Returns a JSON contract for Flutter. Resolve `manifest_path` against the API base URL and pass the resulting URL to an HLS-capable player.
  ///
  /// [quality] - Preferred quality.
  @GET('/api/video/{anime_id}/episodes/{episode_number}/playback')
  Future<PlaybackInfoDto> getApiVideoAnimeIdEpisodesEpisodeNumberPlayback({
    @Path('anime_id') required int animeId,
    @Path('episode_number') required int episodeNumber,
    @Query('quality') QualityTypeDto? quality = QualityTypeDto.value720,
  });

  /// Get a rewritten HLS manifest.
  ///
  /// Returns an HLS manifest whose resources use short-lived signed API paths.
  ///
  /// [quality] - Preferred quality.
  @GET('/api/video/{anime_id}/episodes/{episode_number}/manifest.m3u8')
  Future<String> getApiVideoAnimeIdEpisodesEpisodeNumberManifestM3u8({
    @Path('anime_id') required int animeId,
    @Path('episode_number') required int episodeNumber,
    @Query('quality') QualityTypeDto? quality = QualityTypeDto.value720,
  });

  /// Stream a signed HLS resource.
  ///
  /// Used by URLs embedded in the rewritten manifest. Flutter applications normally do not call this operation directly.
  ///
  /// [range] - Single HTTP byte range.
  @GET('/api/video/{anime_id}/episodes/{episode_number}/resources/{token}')
  @DioResponseType(ResponseType.stream)
  Stream<String> getApiVideoAnimeIdEpisodesEpisodeNumberResourcesToken({
    @Path('anime_id') required int animeId,
    @Path('episode_number') required int episodeNumber,
    @Path('token') required String token,
    @Header('Range') String? range,
  });
}
