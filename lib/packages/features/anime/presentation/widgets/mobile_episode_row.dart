import 'package:material_ui/material_ui.dart';

import '../../domain/models/anime_episode.dart';

class MobileEpisodeRow extends StatelessWidget {
  const MobileEpisodeRow({required this.episode, required this.isWatched, required this.onTap, super.key});
  final AnimeEpisode episode;
  final bool isWatched;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    onTap: onTap,
    label: 'Серия ${episode.number}, ${episode.title}${isWatched ? ', просмотрена' : ''}',
    excludeSemantics: true,
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 8),
      leading: Icon(isWatched ? Icons.check_circle_outline_rounded : Icons.play_circle_outline_rounded),
      title: Text(episode.title),
      subtitle: Text('Серия ${episode.number}${isWatched ? ' · Просмотрена' : ''}'),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    ),
  );
}
