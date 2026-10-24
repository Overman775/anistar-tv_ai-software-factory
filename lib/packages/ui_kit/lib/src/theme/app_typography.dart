import 'package:material_ui/material_ui.dart';

import '../../assets.dart';
import '../widgets/app_layout_scope.dart';

/// TV and touch typography plus content-specific roles used by media surfaces.
abstract final class AppTypography {
  static const fontFamily = FontFamily.manrope;
  static const proseMaxWidth = 720.0;

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

  static TextStyle? detailTitleOf(BuildContext context, {bool wide = false}) {
    final text = Theme.of(context).textTheme;
    if (!AppLayoutScope.isTvOf(context)) {
      return text.headlineSmall?.copyWith(fontSize: 20);
    }

    return wide ? text.headlineLarge?.copyWith(fontSize: 30) : text.headlineMedium?.copyWith(fontSize: 26);
  }

  static TextStyle? descriptionOf(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return AppLayoutScope.isTvOf(context) ? text.bodyLarge?.copyWith(fontSize: 17) : text.bodyMedium;
  }

  static TextStyle? sectionTitleOf(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return AppLayoutScope.isTvOf(context) ? text.headlineSmall : text.titleLarge?.copyWith(fontSize: 19);
  }

  static TextStyle? episodeTitleOf(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return AppLayoutScope.isTvOf(context)
        ? text.titleMedium?.copyWith(fontSize: 18)
        : text.bodyLarge?.copyWith(fontSize: 15);
  }

  static TextStyle? episodeCaptionOf(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return AppLayoutScope.isTvOf(context) ? text.labelMedium : text.bodyMedium;
  }
}
