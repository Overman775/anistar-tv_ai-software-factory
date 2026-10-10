import 'package:material_ui/material_ui.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../theme/app_palette.dart';
import 'tv_skeleton.dart';

/// A shaped skeleton placeholder for images and explicitly-sized areas.
class TvSkeletonBox extends StatelessWidget {
  const TvSkeletonBox({super.key, this.width, this.height, this.borderRadius = AppRadii.medium});

  final BorderRadiusGeometry borderRadius;
  final double? height;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final shape = Bone(width: width ?? double.infinity, height: height, borderRadius: borderRadius);

    return Skeletonizer.maybeOf(context)?.enabled ?? false ? shape : TvSkeleton(isLoading: true, child: shape);
  }
}
