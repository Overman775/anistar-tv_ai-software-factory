import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';

import 'anime_card_actions.dart';

class MobileAnimeSkeleton extends StatelessWidget {
  const MobileAnimeSkeleton({required this.title, required this.showFavorite, super.key});

  final String title;
  final bool showFavorite;

  @override
  Widget build(BuildContext context) => ListView(
    padding: EdgeInsets.fromLTRB(
      AppLayoutScope.horizontalPaddingOf(context),
      12,
      AppLayoutScope.horizontalPaddingOf(context),
      32,
    ),
    children: [
      Semantics(header: true, child: Text(title, style: AppContentTypography.detailTitleOf(context))),
      const SizedBox(height: AppSpacing.lg),
      AnimeCardActions(showFavorite: showFavorite),
      const SizedBox(height: AppSpacing.xl),
      AppSectionHeader(title: 'Серии', titleStyle: AppContentTypography.sectionTitleOf(context)),
      const SizedBox(height: AppSpacing.md),
      Semantics(
        label: 'Загрузка серий',
        liveRegion: true,
        child: const ExcludeSemantics(
          child: TvSkeleton(
            isLoading: true,
            child: Column(
              spacing: AppSpacing.md,
              children: [
                TvSkeletonBox(height: 92, borderRadius: AppRadii.large),
                TvSkeletonBox(height: 92, borderRadius: AppRadii.large),
                TvSkeletonBox(height: 92, borderRadius: AppRadii.large),
              ],
            ),
          ),
        ),
      ),
    ],
  );
}
