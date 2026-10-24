import 'package:material_ui/material_ui.dart';

import 'app_typography.dart';

/// Local text roles for catalog cards and anime details, without changing controls.
abstract final class AppContentTypography {
  static TextStyle? cardTitleOf(BuildContext context) => AppTypography.cardTitleOf(context);

  static TextStyle? cardCaptionOf(BuildContext context) => AppTypography.cardCaptionOf(context);

  static TextStyle? detailTitleOf(BuildContext context, {bool wide = false}) =>
      AppTypography.detailTitleOf(context, wide: wide);

  static TextStyle? descriptionOf(BuildContext context) => AppTypography.descriptionOf(context);

  static TextStyle? sectionTitleOf(BuildContext context) => AppTypography.sectionTitleOf(context);

  static TextStyle? episodeTitleOf(BuildContext context) => AppTypography.episodeTitleOf(context);

  static TextStyle? episodeCaptionOf(BuildContext context) => AppTypography.episodeCaptionOf(context);
}
