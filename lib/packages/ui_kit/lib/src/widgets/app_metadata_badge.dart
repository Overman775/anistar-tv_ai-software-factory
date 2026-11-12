import 'package:material_ui/material_ui.dart';

import '../theme/app_palette.dart';
import 'app_icon.dart';
import 'app_layout_scope.dart';

/// Non-interactive card metadata with a shared contour and readable surface.
class AppMetadataBadge extends StatelessWidget {
  const AppMetadataBadge({required this.icon, this.semanticLabel, this.label, super.key});

  static const double _iconSize = 16;
  static const _standardPadding = EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs);

  final IconData icon;
  final String? semanticLabel;
  final String? label;

  EdgeInsets _padding(BuildContext context, double width, TextStyle style) {
    if (!width.isFinite || label == null) return _standardPadding;

    final painter = TextPainter(
      text: TextSpan(text: label, style: style),
      textScaler: MediaQuery.textScalerOf(context),
      textDirection: Directionality.of(context),
      maxLines: 1,
    )..layout();
    final budget = width - _iconSize - AppSpacing.xs - painter.width;
    painter.dispose();
    // Keep a trailing pixel for the contour when fractional glyph advances round up.
    final left = (budget - 1).clamp(0.0, AppSpacing.sm);
    final right = (budget - left).clamp(0.0, AppSpacing.sm);

    return EdgeInsets.fromLTRB(left, AppSpacing.xs, right, AppSpacing.xs);
  }

  @override
  Widget build(BuildContext context) {
    final style = DefaultTextStyle.of(context).style
        .merge(Theme.of(context).textTheme.labelMedium)
        .copyWith(
          color: AppPalette.textPrimary,
          fontSize: AppLayoutScope.isTvOf(context) ? 16 : 14,
          fontWeight: FontWeight.w700,
        );

    return Semantics(
      label: semanticLabel,
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: const BoxDecoration(color: AppPalette.badge, borderRadius: AppRadii.small),
        child: LayoutBuilder(
          builder: (context, constraints) => Padding(
            padding: _padding(context, constraints.maxWidth, style),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppIcon.fromMaterial(icon, color: AppPalette.primary, size: _iconSize),
                if (label case final text?) ...[
                  const SizedBox(width: AppSpacing.xs),
                  Flexible(
                    child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: style),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
