import 'package:flutter/material.dart';
import 'package:ui_kit/ui_kit.dart';

/// Catalog-owned placeholder layout. Grid decisions remain inside the feature.
class CatalogSkeleton extends StatelessWidget {
  const CatalogSkeleton({super.key});

  int _columnCount(double width) {
    if (width >= 1700) return 6;
    if (width >= 1180) return 5;
    if (width >= 820) return 4;

    return 3;
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => TvSkeleton(
      isLoading: true,
      child: CustomScrollView(
        physics: const NeverScrollableScrollPhysics(),
        slivers: [
          const SliverPadding(
            padding: EdgeInsets.fromLTRB(AppSpacing.xxl, AppSpacing.lg, AppSpacing.xxl, AppSpacing.md),
            sliver: SliverToBoxAdapter(
              child: SizedBox(
                width: 280,
                height: 34,
                child: DecoratedBox(decoration: BoxDecoration(color: AppPalette.surface)),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.xxl, AppSpacing.sm, AppSpacing.xxl, 72),
            sliver: SliverGrid.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: _columnCount(constraints.maxWidth),
                childAspectRatio: 0.68,
                crossAxisSpacing: AppSpacing.lg,
                mainAxisSpacing: AppSpacing.xl,
              ),
              itemCount: _columnCount(constraints.maxWidth) * 2,
              itemBuilder: (_, _) => const DecoratedBox(
                decoration: BoxDecoration(color: AppPalette.surface, borderRadius: AppRadii.large),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
