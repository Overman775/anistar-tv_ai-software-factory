import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';

import '../../catalog/presentation/widgets/catalog_layout.dart';

class SearchLoading extends StatelessWidget {
  const SearchLoading({super.key});

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final tv = AppLayoutScope.isTvOf(context);
      final inset = tv
          ? CatalogLayout.horizontalInset(constraints.maxWidth)
          : AppLayoutScope.horizontalPaddingOf(context);
      final columns = tv ? CatalogLayout.columnCount(constraints.maxWidth) : 2;

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
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    childAspectRatio: AppSizes.posterRatio,
                    crossAxisSpacing: tv ? AppSpacing.lg : AppSpacing.sm,
                    mainAxisSpacing: tv ? AppSpacing.xl : AppSpacing.md,
                  ),
                  itemCount: columns * 2,
                  itemBuilder: (_, _) => const TvSkeletonBox(borderRadius: AppRadii.large),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
