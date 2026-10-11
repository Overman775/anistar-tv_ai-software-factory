import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';

class AnimeMetadataChip extends StatelessWidget {
  const AnimeMetadataChip({required this.label, super.key, this.icon});

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
            Flexible(
              child: Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppPalette.textPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
