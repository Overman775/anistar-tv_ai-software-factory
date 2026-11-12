import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_providers.dart';
import '../watch_history/watched_episodes.dart';
import 'domain/models/anime_episode.dart';
import 'domain/repositories/anime_repository.dart';

final animeRepositoryProvider = Provider<AnimeRepository>(
  (ref) => throw StateError('AnimeRepository must be supplied by the application.'),
);

typedef EpisodeSnapshotWriter = void Function(List<AnimeEpisode>);
typedef AnimeEpisodeSnapshots = ({
  List<AnimeEpisode> Function(int animeId, String slug) available,
  EpisodeSnapshotWriter Function(int animeId, String slug) beginLoad,
});

/// Session memory for episode lists already loaded by a detail screen.
final animeKnownEpisodesProvider = Provider<AnimeEpisodeSnapshots>((ref) {
  ref
    ..watch(animeRepositoryProvider)
    ..watch(authAccessProvider.select((access) => (access.runtimeType, access.account)))
    ..watch(watchHistoryAccountProvider);
  final entries = <(int, String), ({Object load, List<AnimeEpisode> episodes})>{};

  return (
    available: (animeId, slug) => entries[(animeId, slug)]?.episodes ?? const [],
    beginLoad: (animeId, slug) {
      final key = (animeId, slug);
      final load = Object();
      // Pending and failed loads leave the previous list unavailable.
      entries[key] = (load: load, episodes: const []);

      return (episodes) {
        if (identical(entries[key]?.load, load)) {
          entries[key] = (load: load, episodes: List.unmodifiable(episodes));
        }
      };
    },
  );
});
