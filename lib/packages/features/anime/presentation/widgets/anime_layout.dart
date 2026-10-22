import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';

/// Geometry shared by the details page and its loading placeholders.
abstract final class AnimeLayout {
  static double heroHeight(double width, {double textScale = 1}) =>
      baseHeroHeight(width) * textScale.clamp(1, double.infinity);

  static double baseHeroHeight(double width) {
    if (width >= 1200) {
      return 410;
    }

    return width >= 900 ? 380 : 470;
  }

  static int episodeColumns(double _) => 3;

  /// Reserve the same scaled caption and two title lines in loading and ready.
  static double episodeHeight(BuildContext context, double gridWidth, {double? viewportExtent}) {
    final width = (gridWidth - AppSpacing.lg * 2) / episodeColumns(gridWidth);
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    double twoLineHeight(TextStyle? style) {
      final painter = TextPainter(
        text: TextSpan(
          text: 'Серия\nНазвание',
          style: style?.copyWith(fontWeight: FontWeight.w700),
        ),
        textScaler: scaler,
        textDirection: direction,
      )..layout();
      final height = painter.height;
      painter.dispose();

      return height;
    }

    final captionHeight = twoLineHeight(AppContentTypography.episodeCaptionOf(context)) + AppSpacing.xs * 2;
    final titleHeight = twoLineHeight(AppContentTypography.episodeTitleOf(context));

    final naturalHeight = (width < 320 ? width * 9 / 16 : 0) + captionHeight + titleHeight + AppSpacing.lg * 2;
    if (viewportExtent == null || !viewportExtent.isFinite || viewportExtent <= 0) {
      return naturalHeight;
    }
    final focusScale = AppMotion.reducedOf(context) ? 1.0 : AppSizes.cardFocusScale;
    final maximumHeight = viewportExtent / focusScale;

    return naturalHeight > maximumHeight ? maximumHeight : naturalHeight;
  }
}
