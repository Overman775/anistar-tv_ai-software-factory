import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';

import 'catalog_layout.dart';

/// Catalog-owned placeholder layout. Grid decisions remain inside the feature.
class CatalogSkeleton extends StatelessWidget {
  const CatalogSkeleton({super.key});

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => TvSkeleton(
      isLoading: true,
      child: CustomScrollView(
        physics: const NeverScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, 72),
            sliver: SliverGrid.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: CatalogLayout.columnCount(constraints.maxWidth),
                childAspectRatio: 0.68,
                crossAxisSpacing: AppSpacing.lg,
                mainAxisSpacing: AppSpacing.xl,
              ),
              itemCount: CatalogLayout.columnCount(constraints.maxWidth) * 2,
              itemBuilder: (_, _) => const TvSkeletonBox(borderRadius: AppRadii.large),
            ),
          ),
        ],
      ),
    ),
  );
}
