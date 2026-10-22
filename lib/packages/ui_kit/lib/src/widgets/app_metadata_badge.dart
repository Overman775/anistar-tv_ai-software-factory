import 'package:material_ui/material_ui.dart';

import '../theme/app_palette.dart';
import 'app_icon.dart';

/// Non-interactive card metadata with a shared contour and readable surface.
class AppMetadataBadge extends StatelessWidget {
  const AppMetadataBadge({required this.icon, required this.semanticLabel, this.label, super.key});

  final IconData icon;
  final String semanticLabel;
  final String? label;

  @override
  Widget build(BuildContext context) => Semantics(
    label: semanticLabel,
    excludeSemantics: true,
    child: DecoratedBox(
      decoration: const BoxDecoration(
        color: AppPalette.badge,
        borderRadius: AppRadii.small,
        border: Border.fromBorderSide(BorderSide(color: AppPalette.outline)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xs),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppIcon.fromMaterial(icon, color: AppPalette.primary, size: 20),
            if (label case final text?) ...[
              const SizedBox(width: AppSpacing.xs),
              Text(
                text,
                style: Theme.of(context).textTheme.labelMedium
                    ?.copyWith(color: AppPalette.textPrimary, fontSize: 14, fontWeight: FontWeight.w700),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}
