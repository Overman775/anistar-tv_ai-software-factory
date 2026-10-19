import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';

import '../../support/test_app.dart';

void main() {
  for (final mobile in [false, true]) {
    testWidgets('local content roles preserve theme identity and the 14 pixel floor mobile=$mobile', (tester) async {
      final child = Builder(
        builder: (context) {
          final text = Theme.of(context).textTheme;
          final roles = [
            (AppContentTypography.cardTitleOf(context), text.titleSmall),
            (AppContentTypography.cardCaptionOf(context), mobile ? text.labelMedium : text.labelLarge),
            (AppContentTypography.detailTitleOf(context), mobile ? text.headlineSmall : text.headlineMedium),
            (AppContentTypography.detailTitleOf(context, wide: true), mobile ? text.headlineSmall : text.headlineLarge),
            (AppContentTypography.descriptionOf(context), mobile ? text.bodyMedium : text.bodyLarge),
            (AppContentTypography.sectionTitleOf(context), mobile ? text.titleLarge : text.headlineSmall),
            (AppContentTypography.episodeTitleOf(context), mobile ? text.bodyLarge : text.titleMedium),
            (AppContentTypography.episodeCaptionOf(context), mobile ? text.bodyMedium : text.labelMedium),
          ];
          for (final (role, base) in roles) {
            if (role == null || base == null) {
              fail('Production theme must provide every content role');
            }
            final size = role.fontSize;
            final baseSize = base.fontSize;
            if (size == null || baseSize == null) {
              fail('Content roles must have an explicit logical font size');
            }
            expect(size, greaterThanOrEqualTo(14));
            expect(baseSize - size, inInclusiveRange(0, 2));
            expect(role.copyWith(fontSize: base.fontSize), base, reason: 'only the local size may change');
            if (base.fontSize == 14) {
              expect(size, 14, reason: 'existing minimum-size roles must remain unchanged');
            }
          }
          expect(text.titleMedium?.fontSize, mobile ? 16 : 19, reason: 'global controls keep the theme scale');

          return const SizedBox.shrink();
        },
      );
      if (mobile) {
        await pumpMobileApp(tester, child);
      } else {
        await pumpTvApp(tester, child);
      }
    });
  }
}
