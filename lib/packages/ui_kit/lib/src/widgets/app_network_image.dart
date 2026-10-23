import 'package:cached_network_image/cached_network_image.dart';
import 'package:material_ui/material_ui.dart';

import '../theme/app_palette.dart';
import 'app_icon.dart';
import 'tv_skeleton_box.dart';

/// Shared cached remote image with TV-appropriate loading and error states.
class AppNetworkImage extends StatelessWidget {
  const AppNetworkImage({
    required this.imageUrl,
    super.key,
    this.borderRadius = BorderRadius.zero,
    this.errorWidget,
    this.placeholder,
    this.fit = BoxFit.cover,
    this.height,
    this.semanticLabel,
    this.width,
    this.animateLoading = true,
    this.resizeToLayout = true,
    this.fallbackImageUrl,
  });

  final BorderRadiusGeometry borderRadius;
  final bool animateLoading;

  /// Disable for shared posters: changing decode keys during a Hero flight
  /// would replace an already decoded image with a loading placeholder.
  final bool resizeToLayout;
  final Widget? errorWidget;
  final Widget? placeholder;
  final BoxFit fit;
  final double? height;
  final String? imageUrl;

  /// Keep the source poster visible while a different detail image loads.
  final String? fallbackImageUrl;
  final String? semanticLabel;
  final double? width;

  bool _hasValidUrl(String? value) {
    final uri = Uri.tryParse(value ?? '');

    return uri != null && (uri.scheme == 'https' || uri.scheme == 'http') && uri.host.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final url = imageUrl;
    final previousUrl = fallbackImageUrl;
    final hasPrevious = previousUrl != url && _hasValidUrl(previousUrl);
    final previous = hasPrevious
        ? AppNetworkImage(imageUrl: previousUrl, fit: fit, animateLoading: false, resizeToLayout: false)
        : null;
    final fallback = SizedBox(
      width: width,
      height: height,
      child:
          errorWidget ??
          const ColoredBox(
            color: AppPalette.surfaceElevated,
            child: Center(child: AppIcon(AppIconType.circleAlert, color: AppPalette.textSecondary, size: 48)),
          ),
    );

    if (url == null || !_hasValidUrl(url)) {
      return Semantics(
        label: semanticLabel,
        image: true,
        child: ClipRRect(borderRadius: borderRadius, child: previous ?? fallback),
      );
    }

    return Semantics(
      label: semanticLabel,
      image: true,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final pixelRatio = MediaQuery.devicePixelRatioOf(context);
          final decodeWidth = width ?? (constraints.hasBoundedWidth ? constraints.maxWidth : null);
          final decodeHeight = height ?? (constraints.hasBoundedHeight ? constraints.maxHeight : null);

          // Resize on one axis to retain the source aspect ratio. Keep the
          // original disk cache so a detail/Hero surface can decode it larger.
          final cacheWidth = resizeToLayout && decodeWidth != null && decodeWidth.isFinite && decodeWidth > 0
              ? (decodeWidth * pixelRatio).ceil()
              : null;
          final cacheHeight =
              resizeToLayout && cacheWidth == null && decodeHeight != null && decodeHeight.isFinite && decodeHeight > 0
              ? (decodeHeight * pixelRatio).ceil()
              : null;

          final image = CachedNetworkImage(
            imageUrl: url,
            width: width,
            height: height,
            fit: fit,
            memCacheWidth: cacheWidth,
            memCacheHeight: cacheHeight,
            fadeInDuration: animateLoading ? AppMotion.durationOf(context, AppMotion.fast) : Duration.zero,
            fadeOutDuration: animateLoading ? AppMotion.durationOf(context, AppMotion.fast) : Duration.zero,
            placeholder: (_, _) => previous != null
                ? SizedBox(width: width, height: height)
                : placeholder ?? TvSkeletonBox(width: width, height: height, borderRadius: borderRadius),
            errorWidget: (_, _, _) => previous != null ? SizedBox(width: width, height: height) : fallback,
          );

          return ClipRRect(
            borderRadius: borderRadius,
            child: previous == null
                ? image
                : Stack(
                    fit: StackFit.passthrough,
                    children: [
                      Positioned.fill(child: ExcludeSemantics(child: previous)),
                      image,
                    ],
                  ),
          );
        },
      ),
    );
  }
}
