import 'package:material_ui/material_ui.dart';

import '../widgets/app_layout_scope.dart';

/// Local text roles for catalog cards and anime details, without changing controls.
abstract final class AppContentTypography {
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
