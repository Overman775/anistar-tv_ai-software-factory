import 'anistar_video_source_dto.dart';

/// Number identifies an episode only within the requested anime.
final class AnistarEpisodeDto {
  final int number;
  final bool isWatched;
  final Uri? previewUri;
  final List<AnistarVideoSourceDto> sources;
  final String title;

  AnistarEpisodeDto({
    required this.number,
    required this.title,
    required List<AnistarVideoSourceDto> sources,
    this.previewUri,
    this.isWatched = false,
  }) : sources = List.unmodifiable(sources);
}
