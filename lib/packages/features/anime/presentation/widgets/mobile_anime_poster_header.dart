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
    builder: (context, constraints) => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: (constraints.maxWidth * 0.32).clamp(88.0, constraints.maxWidth >= 568 ? 104.0 : 144.0),
          child: AspectRatio(
            aspectRatio: 2 / 3,
            child: ClipRRect(
              borderRadius: AppRadii.large,
              child: posterUri == null
                  ? const ColoredBox(
                      color: AppPalette.surfaceElevated,
                      child: Center(child: Icon(Icons.image_outlined, color: AppPalette.textSecondary)),
                    )
                  : TvPosterHero(
                      tag: 'anime-poster-$animeId',
                      imageUrl: posterUri.toString(),
                      fallbackImageUrl: fallbackPosterUri?.toString(),
                      semanticLabel: title,
                    ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(child: metadata),
      ],
    ),
  );
}
