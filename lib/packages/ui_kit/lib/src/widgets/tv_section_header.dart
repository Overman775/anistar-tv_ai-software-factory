import 'package:material_ui/material_ui.dart';

import '../theme/app_palette.dart';

/// Consistent TV-scale section heading with an optional counter or action.
class TvSectionHeader extends StatelessWidget {
  const TvSectionHeader({required this.title, super.key, this.subtitle, this.trailing});

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final subtitleText = subtitle;

    final heading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: textTheme.headlineSmall?.copyWith(color: AppPalette.textPrimary)),
        if (subtitleText != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(subtitleText, style: textTheme.bodyLarge?.copyWith(color: AppPalette.textSecondary)),
        ],
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) => constraints.maxWidth < 500
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                heading,
                if (trailing case final trailing?) ...[const SizedBox(height: AppSpacing.sm), trailing],
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(child: heading),
                if (trailing case final trailing?) ...[const SizedBox(width: AppSpacing.md), trailing],
              ],
            ),
    );
  }
}
