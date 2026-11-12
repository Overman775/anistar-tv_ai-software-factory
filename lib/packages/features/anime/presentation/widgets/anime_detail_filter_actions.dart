import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';

import '../../../catalog/domain/models/catalog_filter.dart';
import '../../../common/presentation/rating_presentation.dart';
import 'anime_detail_filter_groups.dart';
import 'anime_filter_row.dart';

class AnimeDetailFilterActions extends StatelessWidget {
  const AnimeDetailFilterActions({
    required this.groups,
    required this.focusNodes,
    required this.onSelected,
    this.onFocused,
    this.rating,
    super.key,
  });

  final AnimeDetailFilterGroups groups;
  final Map<String, FocusNode> focusNodes;
  final ValueChanged<CatalogFilter> onSelected;
  final ValueChanged<int>? onFocused;
  final RatingPresentation? rating;

  static const _labelWidth = 96.0;
  static const _starSize = 20.0;

  static TextSpan _ratingSpan(BuildContext context, RatingPresentation rating) => TextSpan(
    style: DefaultTextStyle.of(context).style.merge(Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: 16)),
    children: [
      TextSpan(
        text: rating.label,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      const TextSpan(
        text: ' /\u00a010',
        style: TextStyle(color: AppPalette.textSecondary, fontWeight: FontWeight.w400),
      ),
    ],
  );

  static TextStyle? _headingStyle(BuildContext context) =>
      Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: 16, color: AppPalette.textSecondary);

  static double _textWidth(BuildContext context, TextSpan span) {
    final painter = TextPainter(
      text: span,
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      locale: Localizations.maybeLocaleOf(context),
    )..layout();
    final width = painter.width.ceilToDouble();
    painter.dispose();

    return width;
  }

  double _labelWidthOf(BuildContext context) {
    if (MediaQuery.textScalerOf(context).scale(16) <= 16) return _labelWidth;

    final style = DefaultTextStyle.of(context).style.merge(_headingStyle(context));
    final headings = [if (rating != null) 'Рейтинг', for (final row in groups.rows) row.heading];
    return headings.fold(
      _labelWidth,
      (width, heading) => math.max(width, _textWidth(context, TextSpan(text: heading, style: style))),
    );
  }

  double minimumWidthOf(BuildContext context) {
    const minimumValueWidth = 96.0;
    final value = rating;
    final ratingWidth = value == null
        ? 0.0
        : _starSize + AppSpacing.sm + _textWidth(context, _ratingSpan(context, value));

    return _labelWidthOf(context) + AppSpacing.sm + math.max(minimumValueWidth, ratingWidth);
  }

  @override
  Widget build(BuildContext context) {
    final labelWidth = _labelWidthOf(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppSpacing.sm,
      children: [
        if (rating case final value?)
          _AnimeMetadataRow(
            heading: 'Рейтинг',
            labelWidth: labelWidth,
            child: Semantics(
              label: value.semanticLabel,
              child: ExcludeSemantics(
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: AppSpacing.sm,
                  children: [
                    const AppIcon(AppIconType.star, size: _starSize, color: AppPalette.secondary),
                    Text.rich(_ratingSpan(context, value), softWrap: false),
                  ],
                ),
              ),
            ),
          ),
        for (final row in groups.rows)
          _AnimeMetadataRow(
            heading: row.heading,
            labelWidth: labelWidth,
            child: AnimeFilterRow.metadata(
              values: row.values,
              focusNodes: focusNodes,
              filterIndices: groups.indices,
              onSelected: onSelected,
              onFocused: onFocused,
            ),
          ),
      ],
    );
  }
}

class _AnimeMetadataRow extends StatelessWidget {
  const _AnimeMetadataRow({required this.heading, required this.labelWidth, required this.child});

  final String heading;
  final double labelWidth;
  final Widget child;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      SizedBox(
        width: labelWidth,
        child: Text(heading, style: AnimeDetailFilterActions._headingStyle(context)),
      ),
      const SizedBox(width: AppSpacing.sm),
      Expanded(child: child),
    ],
  );
}
