import 'package:material_ui/material_ui.dart';

class CatalogTabs extends StatelessWidget implements PreferredSizeWidget {
  const CatalogTabs({required this.favoritesOnly, required this.onSelected, super.key});

  final bool favoritesOnly;
  final ValueChanged<bool> onSelected;

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    final selectedColor = Theme.of(context).colorScheme.primaryContainer;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40).copyWith(bottom: 8),
      child: Row(
        children: [
          Semantics(
            selected: !favoritesOnly,
            child: TextButton(
              key: const ValueKey('catalog-tab-false'),
              onPressed: () => onSelected(false),
              style: TextButton.styleFrom(backgroundColor: favoritesOnly ? null : selectedColor),
              child: const Text('Главная'),
            ),
          ),
          const SizedBox(width: 16),
          Semantics(
            selected: favoritesOnly,
            child: TextButton(
              key: const ValueKey('catalog-tab-true'),
              onPressed: () => onSelected(true),
              style: TextButton.styleFrom(backgroundColor: favoritesOnly ? selectedColor : null),
              child: const Text('Избранное'),
            ),
          ),
        ],
      ),
    );
  }
}
