import 'package:flutter/material.dart';
import 'package:ui_kit/ui_kit.dart';

class CatalogHeading extends StatelessWidget {
  const CatalogHeading({required this.itemCount, super.key});

  final int itemCount;

  @override
  Widget build(BuildContext context) => TvSectionHeader(
    title: 'Каталог',
    subtitle: 'Выберите аниме стрелками на пульте',
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
