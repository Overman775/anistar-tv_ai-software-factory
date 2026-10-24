import 'package:material_ui/material_ui.dart';

import 'app_typography.dart';

/// Typography scale optimised for legibility at TV viewing distance.
abstract final class TvTypography {
  static const fontFamily = AppTypography.fontFamily;
  static const proseMaxWidth = AppTypography.proseMaxWidth;

  static TextTheme apply(TextTheme base) => AppTypography.tv(base);
}
