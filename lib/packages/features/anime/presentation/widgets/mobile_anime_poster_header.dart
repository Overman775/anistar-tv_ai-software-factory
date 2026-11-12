import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';

/// Touch poster and metadata stay stacked at every orientation.
class MobileAnimePosterHeader extends StatelessWidget {
  const MobileAnimePosterHeader({
    required this.title,
    required this.metadata,
    this.posterUri,
    this.fallbackPosterUri,
    super.key,
  });

  final String title;
  final Uri? posterUri;
  final Uri? fallbackPosterUri;
  final Widget metadata;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: AppSpacing.lg,
    children: [
      Center(
        child: AnimeDetailsPoster(
          title: title,
          posterUri: posterUri,
          fallbackPosterUri: fallbackPosterUri,
          maxWidth: 240,
        ),
      ),
      metadata,
    ],
  );
}

/// Displays the decoded poster at its source aspect ratio on either profile.
class AnimeDetailsPoster extends StatelessWidget {
  const AnimeDetailsPoster({
    required this.title,
    required this.posterUri,
    required this.fallbackPosterUri,
    required this.maxWidth,
    super.key,
  });

  final String title;
  final Uri? posterUri;
  final Uri? fallbackPosterUri;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    const loading = AspectRatio(aspectRatio: AppSizes.posterRatio, child: TvSkeletonBox());
    const unavailable = AspectRatio(
      aspectRatio: AppSizes.posterRatio,
      child: ColoredBox(
        color: AppPalette.surfaceElevated,
        child: Center(child: AppIcon(AppIconType.circleAlert, color: AppPalette.textSecondary, size: 48)),
      ),
    );
    final fallback = fallbackPosterUri;
    final primary = posterUri ?? fallback;
    final previous = fallback == null || fallback == primary
        ? null
        : ExcludeSemantics(
            child: AppNetworkImage(
              imageUrl: fallback.toString(),
              fit: BoxFit.contain,
              animateLoading: false,
              placeholder: loading,
              errorWidget: unavailable,
            ),
          );

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: AppNetworkImage(
        imageUrl: primary?.toString(),
        fit: BoxFit.contain,
        semanticLabel: title,
        animateLoading: false,
        placeholder: previous ?? loading,
        errorWidget: previous ?? unavailable,
      ),
    );
  }
}
