import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';

import '../../catalog/presentation/widgets/catalog_skeleton.dart';

class SearchLoading extends StatelessWidget {
  const SearchLoading({super.key});

  @override
  Widget build(BuildContext context) {
    if (AppLayoutScope.isTvOf(context)) {
      return const CatalogSkeleton(title: 'Ищем аниме…');
    }
    final inset = AppLayoutScope.horizontalPaddingOf(context);

    return TvSkeleton(
      isLoading: true,
      child: Padding(
        padding: EdgeInsets.fromLTRB(inset, AppSpacing.md, inset, AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Ищем аниме…', style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: AppSpacing.lg),
            Expanded(
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: AppSizes.posterRatio,
                  crossAxisSpacing: AppSpacing.sm,
                  mainAxisSpacing: AppSpacing.md,
                ),
                itemCount: 4,
                itemBuilder: (_, _) => const TvSkeletonBox(borderRadius: AppRadii.large),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
