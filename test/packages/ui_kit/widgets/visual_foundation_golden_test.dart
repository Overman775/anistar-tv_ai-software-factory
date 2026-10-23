import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';

import '../../../support/test_app.dart';

void main() {
  for (final mobile in [false, true]) {
    testWidgets('shared visual foundation ${mobile ? 'mobile' : 'tv'}', (tester) async {
      final gallery = SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 16,
            children: [
              const AnistarLogo(size: 64),
              Row(
                spacing: 12,
                children: [
                  AppButton(
                    label: 'Смотреть',
                    icon: const AppIcon(AppIconType.play),
                    autofocus: true,
                    onPressed: () => fail('Unexpected activation'),
                  ),
                  AppButton(
                    label: 'Отмена',
                    variant: AppButtonVariant.neutral,
                    onPressed: () => fail('Unexpected activation'),
                  ),
                ],
              ),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: 150,
                    child: MediaCard(
                      label: 'Название аниме',
                      caption: '2026 · 12 серий',
                      onPressed: () => fail('Unexpected activation'),
                    ),
                  ),
                  SizedBox(
                    width: 150,
                    child: MediaCard(
                      label: 'Избранное',
                      caption: 'Смотрю',
                      selected: true,
                      showBookmark: true,
                      onPressed: () => fail('Unexpected activation'),
                    ),
                  ),
                ],
              ),
              SizedBox(
                width: 340,
                child: MediaCard(
                  label: 'Серия 2',
                  caption: 'Продолжить просмотр',
                  variant: MediaCardVariant.episode,
                  onPressed: () => fail('Unexpected activation'),
                ),
              ),
              Row(
                spacing: 12,
                children: [
                  for (final symbol in [
                    AppIconType.home,
                    AppIconType.search,
                    AppIconType.heart,
                    AppIconType.user,
                    AppIconType.funnel,
                  ])
                    AppIcon(symbol),
                ],
              ),
            ],
          ),
        ),
      );
      if (mobile) {
        await pumpMobileApp(tester, gallery);
      } else {
        await pumpTvApp(tester, gallery, size: wideTvSize);
      }
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/visual_foundation_${mobile ? 'mobile' : 'tv'}.png'),
      );
    }, tags: ['golden']);
  }
}
