import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';

import '../../domain/models/anime_episode.dart';
import 'episode_caption.dart';

class MobileEpisodeRow extends StatelessWidget {
  const MobileEpisodeRow({required this.episode, required this.onTap, required this.isWatched, super.key});

  final AnimeEpisode episode;
  final bool isWatched;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final watched = isWatched || episode.isWatched;
    final caption = EpisodeCaption(number: episode.number, title: episode.title);

    return MediaCard(
      variant: MediaCardVariant.episode,
      label: caption.numberLabel,
      caption: caption.descriptiveTitle,
      semanticLabel: caption.semanticLabel(isWatched: watched),
      imageUrl: episode.previewUri?.toString(),
      onPressed: onTap,
      badges: [if (watched) const AppIcon(AppIconType.check, size: 20, color: AppPalette.success)],
    );
  }
}
