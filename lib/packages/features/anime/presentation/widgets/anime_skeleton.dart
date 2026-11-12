import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';

import 'anime_layout.dart';

/// Keeps the known title readable and reserves the episode row during loading.
class AnimeSkeleton extends StatelessWidget {
  const AnimeSkeleton({required this.title, super.key});

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl, vertical: AppSpacing.lg),
    child: LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: AppSpacing.lg,
          children: [
            Semantics(header: true, child: Text(title, style: AppContentTypography.detailTitleOf(context))),
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
                      spacing: AppSpacing.lg,
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
