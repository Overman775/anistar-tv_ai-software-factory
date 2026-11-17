import 'package:material_ui/material_ui.dart';
import 'package:sizer/sizer.dart';
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

  static double get horizontalInset => 3.75.w.clamp(36.0, 48.0);

  static double get verticalInset => 3.34.h.clamp(18.0, 24.0);

  static double columnGapOf(BuildContext _) => 1.88.w.clamp(18.0, 24.0);

  static double rowGapOf(BuildContext _) => 4.45.h.clamp(24.0, 32.0);

  /// Reserve the same scaled caption and two title lines in loading and ready.
  static double episodeHeight(BuildContext context, double gridWidth) {
    final width = (gridWidth - columnGapOf(context) * (episodeColumns(gridWidth) - 1)) / episodeColumns(gridWidth);
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
