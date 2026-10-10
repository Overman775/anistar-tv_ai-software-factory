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
          const SliverPadding(
            padding: EdgeInsets.fromLTRB(AppSpacing.xxl, AppSpacing.md, AppSpacing.xxl, AppSpacing.sm),
            sliver: SliverToBoxAdapter(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TvSkeletonBox(width: 180, height: 28, borderRadius: AppRadii.small),
                        SizedBox(height: AppSpacing.xs),
                        TvSkeletonBox(width: 360, height: 26, borderRadius: AppRadii.small),
                      ],
                    ),
                  ),
                  SizedBox(width: AppSpacing.md),
                  TvSkeletonBox(width: 140, height: 42, borderRadius: AppRadii.pill),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.xxl, AppSpacing.sm, AppSpacing.xxl, 72),
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
