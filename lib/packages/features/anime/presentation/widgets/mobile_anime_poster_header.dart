import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';

/// Identical poster bounds in loading and ready states preserve the Hero endpoint.
class MobileAnimePosterHeader extends StatelessWidget {
  const MobileAnimePosterHeader({
    required this.animeId,
    required this.title,
    required this.metadata,
    this.posterUri,
    this.fallbackPosterUri,
    super.key,
  });
  final int animeId;
  final String title;
  final Uri? posterUri;
  final Uri? fallbackPosterUri;
  final Widget metadata;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final poster = AspectRatio(
        aspectRatio: AppSizes.posterRatio,
        child: TvPosterHero(
          tag: 'anime-poster-$animeId',
          imageUrl: posterUri?.toString(),
          fallbackImageUrl: fallbackPosterUri?.toString(),
          semanticLabel: title,
        ),
      );
      if (constraints.maxWidth < 720) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            poster,
            const SizedBox(height: AppSpacing.lg),
            metadata,
          ],
        );
      }

      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 200, child: poster),
          const SizedBox(width: AppSpacing.lg),
          Expanded(child: metadata),
        ],
      );
    },
  );
}
