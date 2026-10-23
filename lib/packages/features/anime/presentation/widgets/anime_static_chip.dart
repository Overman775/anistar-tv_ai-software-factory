import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';

class AnimeStaticChip extends StatelessWidget {
  const AnimeStaticChip({required this.label, required this.maxWidth, super.key});

  final String label;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: BoxConstraints(maxWidth: math.min(360, maxWidth)),
    child: DecoratedBox(
      decoration: const BoxDecoration(color: AppPalette.surfaceElevated, borderRadius: AppRadii.medium),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        child: Text(label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppPalette.textPrimary)),
      ),
    ),
  );
}
