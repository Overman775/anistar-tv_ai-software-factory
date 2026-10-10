import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';

class CatalogHeading extends StatelessWidget {
  const CatalogHeading({required this.itemCount, this.favoritesOnly = false, this.showFavoriteHint = false, super.key});

  final bool favoritesOnly;
  final int itemCount;
  final bool showFavoriteHint;

  String _subtitle(double width) {
    if (width < 500) {
      return showFavoriteHint ? 'Нажмите — открыть · удерживайте — избранное' : 'Нажмите на карточку, чтобы открыть';
    }

    return showFavoriteHint ? 'OK — открыть · удерживать OK — избранное' : 'Выберите аниме стрелками на пульте';
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => TvSectionHeader(
      title: favoritesOnly ? 'Избранное' : 'Каталог',
      subtitle: _subtitle(constraints.maxWidth),
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
    ),
  );
}
