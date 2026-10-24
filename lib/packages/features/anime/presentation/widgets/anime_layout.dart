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
  static double episodeHeight(BuildContext context, double gridWidth) {
    final width = (gridWidth - AppSpacing.lg * 2) / episodeColumns(gridWidth);
    const sample = 'Серия\nНазвание';

    return MediaCardMetrics(
      width: width,
      label: sample,
      caption: sample,
      showCaption: true,
      titleStyle: AppContentTypography.episodeTitleOf(context)
          ?.copyWith(color: AppPalette.textPrimary, fontWeight: FontWeight.w600),
      captionStyle: AppContentTypography.episodeCaptionOf(context)?.copyWith(color: AppPalette.textSecondary),
      textScaler: MediaQuery.textScalerOf(context),
      direction: Directionality.of(context),
    ).episodeHeight;
  }
}
