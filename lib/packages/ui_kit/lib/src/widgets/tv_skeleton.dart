import 'package:material_ui/material_ui.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../theme/app_palette.dart';

/// Generic shimmer wrapper for feature-owned loading layouts.
class TvSkeleton extends StatelessWidget {
  const TvSkeleton({required this.child, required this.isLoading, super.key});

  final Widget child;
  final bool isLoading;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    excluding: isLoading,
    child: ExcludeFocus(
      excluding: isLoading,
      child: IgnorePointer(
        ignoring: isLoading,
        child: Skeletonizer(
          enabled: isLoading,
          effect: AppMotion.reducedOf(context)
              ? const SolidColorEffect(color: AppPalette.surfaceElevated)
              : const ShimmerEffect(
                  duration: AppMotion.shimmer,
                  baseColor: AppPalette.surfaceElevated,
                  highlightColor: AppPalette.outline,
                ),
          child: child,
        ),
      ),
    ),
  );
}
