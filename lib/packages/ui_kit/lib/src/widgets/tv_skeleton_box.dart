import 'package:material_ui/material_ui.dart';

import '../theme/app_palette.dart';
import 'tv_skeleton.dart';

/// A shaped skeleton placeholder for images and explicitly-sized areas.
class TvSkeletonBox extends StatelessWidget {
  const TvSkeletonBox({super.key, this.width, this.height, this.borderRadius = AppRadii.medium});

  final BorderRadiusGeometry borderRadius;
  final double? height;
  final double? width;

  @override
  Widget build(BuildContext context) => TvSkeleton(
    isLoading: true,
    child: SizedBox(
      width: width,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(color: AppPalette.surfaceElevated, borderRadius: borderRadius),
      ),
    ),
  );
}
