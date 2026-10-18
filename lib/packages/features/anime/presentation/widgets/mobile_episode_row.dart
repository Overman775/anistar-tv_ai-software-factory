import 'package:material_ui/material_ui.dart';

import '../../domain/models/anime_episode.dart';
import 'episode_caption.dart';

class MobileEpisodeRow extends StatelessWidget {
  const MobileEpisodeRow({required this.episode, required this.isWatched, required this.onTap, super.key});
  final AnimeEpisode episode;
  final bool isWatched;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final caption = EpisodeCaption(number: episode.number, title: episode.title);
    final watched = isWatched || episode.isWatched;
    final description = caption.descriptiveTitle;
    Widget? subtitle;
    if (description != null) {
      subtitle = Text('${caption.numberLabel}${watched ? ' · Просмотрена' : ''}');
    } else if (watched) {
      subtitle = const Text('Просмотрена');
    }

    return Semantics(
      button: true,
      onTap: onTap,
      label: caption.semanticLabel(isWatched: watched),
      excludeSemantics: true,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(vertical: 8),
        leading: Icon(watched ? Icons.check_circle_outline_rounded : Icons.play_circle_outline_rounded),
        title: Text(description ?? caption.numberLabel),
        subtitle: subtitle,
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      ),
    );
  }
}
