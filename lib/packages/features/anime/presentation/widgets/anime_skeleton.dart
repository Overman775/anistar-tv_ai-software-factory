import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';

/// Anime-details placeholder layout. Episode-grid ownership stays in this feature.
class AnimeSkeleton extends StatelessWidget {
  const AnimeSkeleton({super.key});

  int _columnCount(double width) {
    if (width >= 1600) {
      return 4;
    }
    if (width >= 900) {
      return 3;
    }

    return 2;
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => TvSkeleton(
      isLoading: true,
      child: CustomScrollView(
        physics: const NeverScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            sliver: SliverToBoxAdapter(
              child: SizedBox(
                height: constraints.maxWidth >= 1200 ? 410 : 350,
                child: const DecoratedBox(
                  decoration: BoxDecoration(color: AppPalette.surface, borderRadius: AppRadii.large),
                ),
              ),
            ),
          ),
          const SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
            sliver: SliverToBoxAdapter(
              child: SizedBox(
                width: 180,
                height: 28,
                child: DecoratedBox(decoration: BoxDecoration(color: AppPalette.surface)),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.xxl, AppSpacing.lg, AppSpacing.xxl, 72),
            sliver: SliverGrid.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: _columnCount(constraints.maxWidth),
                mainAxisSpacing: AppSpacing.xl,
                crossAxisSpacing: AppSpacing.lg,
                childAspectRatio: 16 / 9,
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
