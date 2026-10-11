import 'contract/anistar_episode_dto.dart';

/// HTML mutation metadata never crosses the client contract.
final class ParsedEpisode {
  final AnistarEpisodeDto episode;
  final String? mediaId;

  const ParsedEpisode(this.episode, this.mediaId);
}
