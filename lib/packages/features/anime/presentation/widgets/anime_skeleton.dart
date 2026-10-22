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
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl, vertical: AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppContentTypography.detailTitleOf(context)),
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: (MediaQuery.sizeOf(context).width * 0.22).clamp(140.0, 240.0),
                        child: AspectRatio(
                          aspectRatio: AppSizes.posterRatio,
                          child: animeId != null && posterUri != null
                              ? TvPosterHero(
                                  tag: 'anime-poster-$animeId',
                                  imageUrl: posterUri.toString(),
                                  semanticLabel: title,
                                )
                              : const TvSkeletonBox(borderRadius: AppRadii.large),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xl),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TvSkeletonBox(height: 28),
                            SizedBox(height: AppSpacing.md),
                            TvSkeletonBox(height: 24),
                            SizedBox(height: AppSpacing.lg),
                            TvSkeletonBox(height: 56),
                            SizedBox(height: AppSpacing.sm),
                            TvSkeletonBox(height: 56),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  const TvSkeletonBox(height: 80),
                ],
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
                    mainAxisExtent: AnimeLayout.episodeHeight(
                      context,
                      constraints.crossAxisExtent,
                      viewportExtent: constraints.viewportMainAxisExtent,
                    ),
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
