import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';

import 'catalog_layout.dart';

/// The first-page placeholders reserve the same poster geometry as the rail.
class CatalogSkeleton extends StatelessWidget {
  const CatalogSkeleton({this.title = 'Каталог аниме', super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    final viewport = MediaQuery.sizeOf(context);
    final width = CatalogLayout.posterWidth(viewport.height);
    final gap = CatalogLayout.posterGap(viewport.width);
    final anchor = CatalogLayout.horizontalInset(viewport.width) + CatalogLayout.focusGutter;
    final height = width / AppSizes.posterRatio;

    return TvSkeleton(
      isLoading: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Padding(
              padding: EdgeInsets.fromLTRB(anchor, 16, anchor, 0),
              child: Align(
                alignment: Alignment.topLeft,
                child: FractionallySizedBox(
                  widthFactor: 2 / 3,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      const heading = TvSkeletonBox(height: 32);
                      final subtitleFits = constraints.maxHeight >= 32 + AppSpacing.md + 20;
                      final descriptionFits = constraints.maxHeight > 32 + 20 + 2 * AppSpacing.md;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: AppSpacing.md,
                        children: [
                          if (subtitleFits) heading else const Flexible(child: heading),
                          if (subtitleFits) const TvSkeletonBox(height: 20, width: 180),
                          if (descriptionFits) const Flexible(child: TvSkeletonBox(height: 48)),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(anchor, 16, anchor, 8),
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ),
          SizedBox(
            height: height + CatalogLayout.railTopPadding + CatalogLayout.railBottomPadding,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(anchor, CatalogLayout.railTopPadding, 0, CatalogLayout.railBottomPadding),
              itemCount: CatalogLayout.defaultPageSize,
              itemBuilder: (_, _) => TvSkeletonBox(width: width, borderRadius: AppRadii.large),
              separatorBuilder: (_, _) => SizedBox(width: gap),
            ),
          ),
        ],
      ),
    );
  }
}
