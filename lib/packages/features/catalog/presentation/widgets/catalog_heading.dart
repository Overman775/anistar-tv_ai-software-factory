import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';

class CatalogHeading extends StatelessWidget {
  const CatalogHeading({required this.itemCount, this.favoritesOnly = false, this.showFavoriteHint = false, super.key});

  final bool favoritesOnly;
  final int itemCount;
  final bool showFavoriteHint;

  @override
  Widget build(BuildContext context) => TvSectionHeader(
    title: favoritesOnly ? 'Избранное' : 'Каталог',
    subtitle: showFavoriteHint ? 'OK — открыть · удерживать OK — избранное' : 'Выберите аниме стрелками на пульте',
    trailing: DecoratedBox(
      decoration: const BoxDecoration(color: AppPalette.surfaceElevated, borderRadius: AppRadii.pill),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        child: Text(
          '$itemCount загружено',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(color: AppPalette.secondary),
        ),
      ),
    ),
  );
}
