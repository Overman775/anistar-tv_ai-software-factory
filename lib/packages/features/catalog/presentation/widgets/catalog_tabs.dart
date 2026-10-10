import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';

class CatalogTabs extends StatelessWidget implements PreferredSizeWidget {
  const CatalogTabs({required this.favoritesOnly, required this.onSelected, super.key});

  final bool favoritesOnly;
  final ValueChanged<bool> onSelected;

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    final selectedColor = Theme.of(context).colorScheme.primaryContainer;
    final side = WidgetStateProperty.resolveWith<BorderSide?>(
      (states) =>
          BorderSide(color: states.contains(WidgetState.focused) ? AppPalette.primary : Colors.transparent, width: 2),
    );
    final style = TextButton.styleFrom(
      minimumSize: const Size(0, 48),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      shape: const RoundedRectangleBorder(borderRadius: AppRadii.pill),
    ).copyWith(side: side);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40).copyWith(bottom: 8),
      child: Row(
        children: [
          Semantics(
            selected: !favoritesOnly,
            child: TextButton(
              key: const ValueKey('catalog-tab-false'),
              onPressed: () => onSelected(false),
              style: style.copyWith(
                backgroundColor: WidgetStatePropertyAll(favoritesOnly ? null : selectedColor),
                foregroundColor: WidgetStatePropertyAll(
                  favoritesOnly ? AppPalette.textSecondary : AppPalette.textPrimary,
                ),
              ),
              child: const Text('Главная'),
            ),
          ),
          const SizedBox(width: 16),
          Semantics(
            selected: favoritesOnly,
            child: TextButton(
              key: const ValueKey('catalog-tab-true'),
              onPressed: () => onSelected(true),
              style: style.copyWith(
                backgroundColor: WidgetStatePropertyAll(favoritesOnly ? selectedColor : null),
                foregroundColor: WidgetStatePropertyAll(
                  favoritesOnly ? AppPalette.textPrimary : AppPalette.textSecondary,
                ),
              ),
              child: const Text('Избранное'),
            ),
          ),
        ],
      ),
    );
  }
}
