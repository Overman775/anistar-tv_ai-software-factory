import 'package:cached_network_image/cached_network_image.dart';
import 'package:material_ui/material_ui.dart';

import '../theme/app_palette.dart';
import 'tv_skeleton_box.dart';

/// Shared cached remote image with TV-appropriate loading and error states.
class AppNetworkImage extends StatelessWidget {
  const AppNetworkImage({
    required this.imageUrl,
    super.key,
    this.borderRadius = BorderRadius.zero,
    this.errorWidget,
    this.fit = BoxFit.cover,
    this.height,
    this.semanticLabel,
    this.width,
    this.animateLoading = true,
  });

  final BorderRadiusGeometry borderRadius;
  final bool animateLoading;
  final Widget? errorWidget;
  final BoxFit fit;
  final double? height;
  final String? imageUrl;
  final String? semanticLabel;
  final double? width;

  bool _hasValidUrl(String? value) {
    final uri = Uri.tryParse(value ?? '');

    return uri != null && (uri.scheme == 'https' || uri.scheme == 'http') && uri.host.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final url = imageUrl;
    final fallback = SizedBox(
      width: width,
      height: height,
      child:
          errorWidget ??
          const ColoredBox(
            color: AppPalette.surfaceElevated,
            child: Center(child: Icon(Icons.broken_image_outlined, color: AppPalette.textSecondary, size: 48)),
          ),
    );

    if (url == null || !_hasValidUrl(url)) {
      return Semantics(label: semanticLabel, image: true, child: fallback);
    }

    return Semantics(
      label: semanticLabel,
      image: true,
      child: ClipRRect(
        borderRadius: borderRadius,
        child: CachedNetworkImage(
          imageUrl: url,
          width: width,
          height: height,
          fit: fit,
          fadeInDuration: animateLoading ? AppMotion.durationOf(context, AppMotion.fast) : Duration.zero,
          fadeOutDuration: animateLoading ? AppMotion.durationOf(context, AppMotion.fast) : Duration.zero,
          placeholder: (_, _) => TvSkeletonBox(width: width, height: height, borderRadius: borderRadius),
          errorWidget: (_, _, _) => fallback,
        ),
      ),
    );
  }
}
