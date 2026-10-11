import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';

import 'mobile_anime_poster_header.dart';

class MobileAnimeSkeleton extends StatelessWidget {
  const MobileAnimeSkeleton({required this.animeId, required this.title, this.posterUri, super.key});
  final int animeId;
  final String title;
  final Uri? posterUri;

  @override
  Widget build(BuildContext context) => TvSkeleton(
    isLoading: true,
    child: ListView(
      padding: EdgeInsets.fromLTRB(
        AppLayoutScope.horizontalPaddingOf(context),
        12,
        AppLayoutScope.horizontalPaddingOf(context),
        32,
      ),
      children: [
        MobileAnimePosterHeader(
          animeId: animeId,
          title: title,
          posterUri: posterUri,
          metadata: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (MediaQuery.sizeOf(context).width >= 600) ...[
                Text(title, style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 12),
              ],
              const TvSkeletonBox(height: 20),
              const SizedBox(height: 12),
              const TvSkeletonBox(height: 20),
              const SizedBox(height: 12),
              const TvSkeletonBox(height: 20),
            ],
          ),
        ),
        if (MediaQuery.sizeOf(context).width < 600) ...[
          const SizedBox(height: 20),
          Text(title, style: Theme.of(context).textTheme.headlineSmall),
        ],
        const SizedBox(height: 16),
        const TvSkeletonBox(height: 48),
        const SizedBox(height: 8),
        const TvSkeletonBox(height: 48),
        const SizedBox(height: 24),
        const TvSkeletonBox(height: 24),
        const SizedBox(height: 12),
        const TvSkeletonBox(height: 80),
        const SizedBox(height: 24),
        const TvSkeletonBox(height: 24),
        const SizedBox(height: 12),
        for (var i = 0; i < 3; i++) ...[const TvSkeletonBox(height: 64), const SizedBox(height: 8)],
      ],
    ),
  );
}
