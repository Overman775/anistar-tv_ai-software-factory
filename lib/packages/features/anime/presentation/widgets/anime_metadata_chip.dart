import 'package:flutter/material.dart';
import 'package:ui_kit/ui_kit.dart';

class AnimeMetadataChip extends StatelessWidget {
  const AnimeMetadataChip({super.key, required this.label, this.icon});

  final IconData? icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final iconValue = icon;

    return DecoratedBox(
      decoration: const BoxDecoration(color: AppPalette.surfaceElevated, borderRadius: AppRadii.pill),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (iconValue != null) ...[
              Icon(iconValue, size: 15, color: AppPalette.success),
              const SizedBox(width: AppSpacing.xs),
            ],
            Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppPalette.textPrimary)),
          ],
        ),
      ),
    );
  }
}
