import 'package:material_ui/material_ui.dart';
import 'package:sizer/sizer.dart';

import '../../assets.dart';
import '../widgets/app_layout_scope.dart';

/// TV and touch typography plus content-specific roles used by media surfaces.
abstract final class AppTypography {
  static const fontFamily = FontFamily.manrope;
  static const proseMaxWidth = 720.0;

  /// Sizer-driven TV base size. The clamp keeps every role readable on small
  /// windows while the system [TextScaler] still scales the result.
  static double _tvSp(double value, double minimum, double maximum) => value.sp.clamp(minimum, maximum);

  static TextTheme tv(TextTheme base) => base
      .apply(fontFamily: fontFamily)
      .copyWith(
        displaySmall: base.displaySmall?.copyWith(
          fontFamily: fontFamily,
          fontWeight: FontWeight.w800,
          letterSpacing: -1,
        ),
        headlineLarge: base.headlineLarge?.copyWith(
          fontFamily: fontFamily,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.6,
        ),
        headlineMedium: base.headlineMedium?.copyWith(
          fontFamily: fontFamily,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.4,
        ),
        headlineSmall: base.headlineSmall?.copyWith(fontFamily: fontFamily, fontWeight: FontWeight.w800),
        titleLarge: base.titleLarge?.copyWith(fontFamily: fontFamily, fontSize: 24, fontWeight: FontWeight.w800),
        titleMedium: base.titleMedium?.copyWith(fontFamily: fontFamily, fontSize: 19, fontWeight: FontWeight.w500),
        titleSmall: base.titleSmall?.copyWith(fontFamily: fontFamily, fontSize: 16, fontWeight: FontWeight.w500),
        bodyLarge: base.bodyLarge?.copyWith(fontFamily: fontFamily, fontSize: 18, height: 1.45),
        bodyMedium: base.bodyMedium?.copyWith(fontFamily: fontFamily, fontSize: 16, height: 1.4),
        bodySmall: base.bodySmall?.copyWith(fontFamily: fontFamily, fontSize: 14, height: 1.4),
        labelMedium: base.labelMedium?.copyWith(fontFamily: fontFamily, fontSize: 14, fontWeight: FontWeight.w500),
        labelSmall: base.labelSmall?.copyWith(fontFamily: fontFamily, fontSize: 14, fontWeight: FontWeight.w500),
        labelLarge: base.labelLarge?.copyWith(
          fontFamily: fontFamily,
          fontSize: 16,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.2,
        ),
      );

  static TextTheme mobile(TextTheme base) => base.copyWith(
    headlineLarge: base.headlineLarge?.copyWith(fontSize: 28, height: 1.2),
    headlineMedium: base.headlineMedium?.copyWith(fontSize: 24, height: 1.25),
    headlineSmall: base.headlineSmall?.copyWith(fontSize: 22, height: 1.25),
    titleLarge: base.titleLarge?.copyWith(fontSize: 20, height: 1.3),
    titleMedium: base.titleMedium?.copyWith(fontSize: 16, height: 1.35),
    bodyLarge: base.bodyLarge?.copyWith(fontSize: 16),
    bodyMedium: base.bodyMedium?.copyWith(fontSize: 14),
    labelLarge: base.labelLarge?.copyWith(fontSize: 14),
  );

  static TextStyle? cardTitleOf(BuildContext context) => Theme.of(context).textTheme.titleSmall?.copyWith(fontSize: 15);

  static TextStyle? cardCaptionOf(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return AppLayoutScope.isTvOf(context) ? text.labelLarge?.copyWith(fontSize: 15) : text.labelMedium;
  }

  static TextStyle? selectedTitleOf(BuildContext context) {
    final text = Theme.of(context).textTheme;
    if (!AppLayoutScope.isTvOf(context)) return text.headlineSmall?.copyWith(fontSize: 20);

    return text.headlineMedium?.copyWith(
      fontFamily: fontFamily,
      fontSize: _tvSp(20, 28, 56),
      fontWeight: FontWeight.w800,
      height: 1.16,
    );
  }

  static TextStyle? railHeadingOf(BuildContext context) {
    final text = Theme.of(context).textTheme;
    if (!AppLayoutScope.isTvOf(context)) return text.headlineSmall;

    return text.titleLarge?.copyWith(
      fontFamily: fontFamily,
      fontSize: _tvSp(14.4, 18, 28),
      fontWeight: FontWeight.w800,
      height: 1.25,
    );
  }

  static TextStyle? railCardTitleOf(BuildContext context) {
    final text = Theme.of(context).textTheme;
    if (!AppLayoutScope.isTvOf(context)) return cardTitleOf(context);

    return text.titleSmall?.copyWith(
      fontFamily: fontFamily,
      fontSize: _tvSp(12, 14, 18),
      fontWeight: FontWeight.w600,
      height: 1.4,
    );
  }

  static TextStyle? genreTitleOf(BuildContext context) {
    final text = Theme.of(context).textTheme;
    if (!AppLayoutScope.isTvOf(context)) return cardTitleOf(context);

    return text.titleSmall?.copyWith(
      fontFamily: fontFamily,
      fontSize: _tvSp(12.5, 14, 16),
      fontWeight: FontWeight.w600,
      height: 1.4,
    );
  }

  static TextStyle? metadataTextOf(BuildContext context) {
    final text = Theme.of(context).textTheme;
    if (!AppLayoutScope.isTvOf(context)) return text.bodyMedium;

    return text.bodyMedium?.copyWith(fontFamily: fontFamily, fontSize: _tvSp(13, 16, 18), height: 1.5);
  }

  static TextStyle? actionTextOf(BuildContext context) {
    final text = Theme.of(context).textTheme;
    if (!AppLayoutScope.isTvOf(context)) return text.labelLarge?.copyWith(fontSize: 16);

    return text.labelLarge?.copyWith(fontFamily: fontFamily, fontSize: _tvSp(13, 14, 16));
  }

  static TextStyle? metadataControlTextOf(BuildContext context) {
    final text = Theme.of(context).textTheme;
    if (!AppLayoutScope.isTvOf(context)) return text.bodyLarge?.copyWith(fontSize: 16);

    return text.bodyMedium?.copyWith(fontFamily: fontFamily, fontSize: _tvSp(13, 14, 16), height: 1.3);
  }

  static TextStyle? searchFieldOf(BuildContext context) {
    final text = Theme.of(context).textTheme;
    if (!AppLayoutScope.isTvOf(context)) return text.bodyLarge?.copyWith(fontSize: 16);

    return text.bodyLarge?.copyWith(fontFamily: fontFamily, fontSize: _tvSp(13, 14, 16));
  }

  static TextStyle? detailTitleOf(BuildContext context, {bool wide = false}) {
    final text = Theme.of(context).textTheme;
    if (!AppLayoutScope.isTvOf(context)) {
      return text.headlineSmall?.copyWith(fontSize: 20);
    }

    return (wide ? text.headlineLarge : text.headlineMedium)?.copyWith(
      fontFamily: fontFamily,
      fontSize: _tvSp(16.5, 22, 26),
      fontWeight: FontWeight.w800,
      height: 1.16,
    );
  }

  static TextStyle? descriptionOf(BuildContext context) {
    final text = Theme.of(context).textTheme;
    if (!AppLayoutScope.isTvOf(context)) return text.bodyMedium;

    return text.bodyLarge?.copyWith(fontFamily: fontFamily, fontSize: _tvSp(13, 16, 18), height: 1.5);
  }

  static TextStyle? sectionTitleOf(BuildContext context) {
    final text = Theme.of(context).textTheme;
    if (!AppLayoutScope.isTvOf(context)) return text.titleLarge?.copyWith(fontSize: 19);

    return text.headlineSmall?.copyWith(
      fontFamily: fontFamily,
      fontSize: _tvSp(15.8, 20, 24),
      fontWeight: FontWeight.w800,
    );
  }

  static TextStyle? episodeTitleOf(BuildContext context) {
    final text = Theme.of(context).textTheme;
    if (!AppLayoutScope.isTvOf(context)) return text.bodyLarge?.copyWith(fontSize: 15);

    return text.titleMedium?.copyWith(fontFamily: fontFamily, fontSize: _tvSp(13.7, 16, 18));
  }

  static TextStyle? episodeCaptionOf(BuildContext context) {
    final text = Theme.of(context).textTheme;
    if (!AppLayoutScope.isTvOf(context)) return text.bodyMedium;

    return text.labelMedium?.copyWith(fontFamily: fontFamily, fontSize: _tvSp(12.5, 14, 16));
  }

  static TextStyle? playerTitleOf(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return text.headlineMedium?.copyWith(
      fontFamily: fontFamily,
      fontSize: _tvSp(15.8, 20, 24),
      fontWeight: FontWeight.w600,
      height: 1.2,
    );
  }

  static TextStyle? playerEpisodeOf(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return text.bodyLarge?.copyWith(fontFamily: fontFamily, fontSize: _tvSp(13.7, 16, 18));
  }

  static TextStyle? playerTimeOf(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return text.bodyLarge?.copyWith(fontFamily: fontFamily, fontSize: _tvSp(13, 14, 16));
  }

  static TextStyle? stateTitleOf(BuildContext context) {
    final text = Theme.of(context).textTheme;
    if (!AppLayoutScope.isTvOf(context)) return text.headlineSmall;

    return text.headlineSmall?.copyWith(fontFamily: fontFamily, fontSize: _tvSp(15.8, 20, 24));
  }

  static TextStyle? stateBodyOf(BuildContext context) {
    final text = Theme.of(context).textTheme;
    if (!AppLayoutScope.isTvOf(context)) return text.bodyLarge;

    return text.bodyLarge?.copyWith(fontFamily: fontFamily, fontSize: _tvSp(13, 16, 18), height: 1.5);
  }
}
