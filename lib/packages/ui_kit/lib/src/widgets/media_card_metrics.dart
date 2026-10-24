import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../theme/app_spacing.dart';

/// Measures the copy area inside an episode card.
///
/// Callers provide already formatted labels and the same styles used to paint
/// them, so layout and scroll calculations share one geometry definition.
class MediaCardMetrics {
  const MediaCardMetrics({
    required this.captionStyle,
    required this.direction,
    required this.label,
    required this.showCaption,
    required this.textScaler,
    required this.titleStyle,
    required this.width,
    this.caption,
    this.minimumHeight,
  });

  final String? caption;
  final TextStyle? captionStyle;
  final TextDirection direction;
  final String label;
  final double? minimumHeight;
  final bool showCaption;
  final TextScaler textScaler;
  final TextStyle? titleStyle;
  final double width;

  double get imageHeight => width / AppSizes.landscapeRatio;

  double get copyHeight {
    final copyWidth = math.max<double>(1, width - AppSpacing.md * 2);
    final titleHeight = _textHeight(label, titleStyle, copyWidth);
    final captionHeight = switch ((showCaption, caption)) {
      (true, final String caption) => _textHeight(caption, captionStyle, copyWidth) + AppSpacing.xs,
      _ => 0.0,
    };

    return AppSpacing.xxl + AppSpacing.md + titleHeight + captionHeight;
  }

  double get episodeHeight => math.max(minimumHeight ?? imageHeight, copyHeight);

  double _textHeight(String text, TextStyle? style, double maxWidth) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: direction,
      textScaler: textScaler,
      maxLines: 2,
    )..layout(maxWidth: maxWidth);
    final height = painter.height;
    painter.dispose();

    return height;
  }
}
