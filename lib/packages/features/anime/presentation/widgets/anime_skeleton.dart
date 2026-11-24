import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';

import 'anime_card_actions.dart';
import 'anime_layout.dart';

/// Keeps the known title readable and reserves the episode row during loading.
class AnimeSkeleton extends StatelessWidget {
  const AnimeSkeleton({required this.title, required this.showFavorite, super.key});

  final String title;
  final bool showFavorite;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.symmetric(horizontal: AnimeLayout.horizontalInset, vertical: AnimeLayout.verticalInset),
    child: LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(header: true, child: Text(title, style: AppContentTypography.detailTitleOf(context))),
            const SizedBox(height: AppSpacing.lg),
            AnimeCardActions(showFavorite: showFavorite),
            SizedBox(height: 2 * AnimeLayout.verticalInset),
            AppSectionHeader(title: 'Серии', titleStyle: AppContentTypography.sectionTitleOf(context)),
            const SizedBox(height: 2 * AppSpacing.sm),
            Semantics(
              label: 'Загрузка серий',
              liveRegion: true,
              child: ExcludeSemantics(
                child: TvSkeleton(
                  isLoading: true,
                  child: SizedBox(
                    height: AnimeLayout.episodeHeight(context, constraints.maxWidth),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      spacing: AnimeLayout.columnGapOf(context),
                      children: [
                        for (var column = 0; column < AnimeLayout.episodeColumns(constraints.maxWidth); column++)
                          const Expanded(child: TvSkeletonBox(borderRadius: AppRadii.large)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
