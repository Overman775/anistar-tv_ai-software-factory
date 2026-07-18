import 'package:flutter/material.dart';
import 'package:ui_kit/ui_kit.dart';

class CatalogHeading extends StatelessWidget {
  const CatalogHeading({super.key, required this.itemCount});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Каталог', style: textTheme.headlineMedium?.copyWith(color: AppPalette.textPrimary)),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Выберите аниме стрелками на пульте',
                style: textTheme.bodyLarge?.copyWith(color: AppPalette.textSecondary),
              ),
            ],
          ),
        ),
        DecoratedBox(
          decoration: const BoxDecoration(color: AppPalette.surfaceElevated, borderRadius: AppRadii.pill),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            child: Text('$itemCount загружено', style: textTheme.labelLarge?.copyWith(color: AppPalette.secondary)),
          ),
        ),
      ],
    );
  }
}
