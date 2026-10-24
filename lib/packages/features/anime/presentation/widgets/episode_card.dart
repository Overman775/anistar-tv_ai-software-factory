import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';

import '../../domain/models/anime_episode.dart';

class EpisodeCard extends StatelessWidget {
  const EpisodeCard({
    required this.episode,
    required this.onTap,
    this.autofocus = false,
    this.focusNode,
    this.isWatched = false,
    this.episodeHeight,
    this.onFocusChanged,
    super.key,
  });

  final AnimeEpisode episode;
  final bool isWatched;
  final double? episodeHeight;
  final VoidCallback onTap;
  final bool autofocus;
  final FocusNode? focusNode;
  final ValueChanged<bool>? onFocusChanged;

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
      episodeHeight: episodeHeight,
      onPressed: onTap,
      autofocus: autofocus,
      focusNode: focusNode,
      onFocusChanged: onFocusChanged,
      badges: [if (watched) const AppIcon(AppIconType.check, size: 20, color: AppPalette.success)],
    );
  }
}
