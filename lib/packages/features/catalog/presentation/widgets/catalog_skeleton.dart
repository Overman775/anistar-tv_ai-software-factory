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
      child: Column(
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: CatalogLayout.inspectorHeight(
                MediaQuery.sizeOf(context).height,
                MediaQuery.textScalerOf(context).scale(16) / 16,
              ),
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: CatalogLayout.horizontalInset(MediaQuery.sizeOf(context).width),
                vertical: MediaQuery.sizeOf(context).width <= 768 ? AppSpacing.lg : AppSpacing.xl,
              ),
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TvSkeletonBox(height: 32),
                  SizedBox(height: AppSpacing.md),
                  TvSkeletonBox(height: 20),
                  SizedBox(height: AppSpacing.md),
                  Flexible(child: TvSkeletonBox(height: 32)),
                ],
              ),
            ),
          ),
          Expanded(
            child: CustomScrollView(
              physics: const NeverScrollableScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    CatalogLayout.horizontalInset(MediaQuery.sizeOf(context).width),
                    AppSpacing.md,
                    CatalogLayout.horizontalInset(MediaQuery.sizeOf(context).width),
                    72,
                  ),
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
        ],
      ),
    ),
  );
}
