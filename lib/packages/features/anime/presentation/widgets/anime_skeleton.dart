import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';

import 'anime_layout.dart';

/// Uses the same hero bounds and padded episode grid as the loaded page.
class AnimeSkeleton extends StatelessWidget {
  const AnimeSkeleton({super.key, this.animeId, this.posterUri, this.title = ''});

  final int? animeId;
  final Uri? posterUri;
  final String title;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => TvSkeleton(
      isLoading: true,
      child: CustomScrollView(
        physics: const NeverScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: SizedBox(
              height: AnimeLayout.heroHeight(constraints.maxWidth),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  constraints.maxWidth < 600 ? AppSpacing.md : AppSpacing.xxl,
                  AppSpacing.lg,
                  constraints.maxWidth < 600 ? AppSpacing.md : AppSpacing.xxl,
                  AppSpacing.xl,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (constraints.maxWidth >= 600)
                      AspectRatio(
                        aspectRatio: 2 / 3,
                        child: animeId != null && posterUri != null
                            ? ClipRRect(
                                borderRadius: AppRadii.large,
                                child: TvPosterHero(
                                  tag: 'anime-poster-$animeId',
                                  imageUrl: posterUri.toString(),
                                  semanticLabel: title,
                                ),
                              )
                            : const TvSkeletonBox(borderRadius: AppRadii.large),
                      ),
                    if (constraints.maxWidth >= 600) const SizedBox(width: AppSpacing.xl),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TvSkeletonBox(width: 220, height: 34, borderRadius: AppRadii.pill),
                          SizedBox(height: AppSpacing.md),
                          TvSkeletonBox(height: 38, borderRadius: AppRadii.small),
                          SizedBox(height: AppSpacing.sm),
                          TvSkeletonBox(width: 260, height: 24, borderRadius: AppRadii.small),
                          SizedBox(height: AppSpacing.md),
                          TvSkeletonBox(height: 22, borderRadius: AppRadii.small),
                          SizedBox(height: AppSpacing.sm),
                          FractionallySizedBox(
                            widthFactor: 0.8,
                            child: TvSkeletonBox(height: 22, borderRadius: AppRadii.small),
                          ),
                          Spacer(),
                          TvSkeletonBox(width: 260, height: 56),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SliverPadding(
            padding: EdgeInsets.fromLTRB(AppSpacing.xxl, AppSpacing.lg, AppSpacing.xxl, AppSpacing.sm),
            sliver: SliverToBoxAdapter(
              child: Align(
                alignment: Alignment.centerLeft,
                child: TvSkeletonBox(width: 140, height: 28, borderRadius: AppRadii.small),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.xxl, AppSpacing.sm, AppSpacing.xxl, 72),
            sliver: SliverLayoutBuilder(
              builder: (context, constraints) {
                final columns = AnimeLayout.episodeColumns(constraints.crossAxisExtent);

                return SliverGrid.builder(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    mainAxisSpacing: AppSpacing.xl,
                    crossAxisSpacing: AppSpacing.lg,
                    childAspectRatio: 16 / 9,
                  ),
                  itemCount: columns * 2,
                  itemBuilder: (_, _) => const TvSkeletonBox(borderRadius: AppRadii.large),
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}
