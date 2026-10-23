import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';

import '../../domain/models/anime_summary.dart';

/// The common poster surface with a discoverable touch action.
class MobileAnimeCard extends StatelessWidget {
  const MobileAnimeCard({
    required this.anime,
    required this.onTap,
    required this.onActions,
    this.isFavorite,
    this.showFavorite = true,
    super.key,
  });

  final AnimeSummary anime;
  final VoidCallback onTap;
  final VoidCallback onActions;
  final bool? isFavorite;
  final bool showFavorite;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      MediaCard(
        label: anime.title,
        caption: anime.year,
        showCaption: false,
        showBookmark: showFavorite && (isFavorite ?? anime.isFavorite) == true,
        imageUrl: anime.posterUri?.toString(),
        heroTag: 'anime-poster-${anime.id}',
        onPressed: onTap,
        onLongPressed: onActions,
      ),
      Positioned(
        top: AppSpacing.sm,
        left: AppSpacing.sm,
        child: SizedBox.square(
          dimension: AppSizes.touchControl,
          child: IconButton(
            key: ValueKey('anime-actions-${anime.id}'),
            tooltip: 'Действия: ${anime.title}',
            onPressed: onActions,
            style: IconButton.styleFrom(backgroundColor: AppPalette.mediaCaptionShade),
            icon: const AppIcon(AppIconType.list),
          ),
        ),
      ),
    ],
  );
}
