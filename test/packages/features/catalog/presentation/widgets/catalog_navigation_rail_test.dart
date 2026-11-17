import 'package:anistar_tv/packages/features/catalog/presentation/widgets/catalog_navigation_rail.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';

import '../../../../../support/test_app.dart';

void main() {
  testWidgets('compact TV menu keeps the avatar visible and labels stable during reversal', (tester) async {
    final expanded = ValueNotifier(false);
    final focus = FocusNode();
    addTearDown(expanded.dispose);
    addTearDown(focus.dispose);
    const label = 'Выйти из аккаунта';
    await pumpTvApp(
      tester,
      Align(
        alignment: Alignment.centerLeft,
        child: ValueListenableBuilder(
          valueListenable: expanded,
          builder: (context, value, _) => CatalogNavigationRail(
            expanded: value,
            accountName: 'Длинное имя пользователя',
            items: [
              (
                key: const ValueKey('catalog-account'),
                icon: Icons.logout,
                label: label,
                focusNode: focus,
                onPressed: () => fail('Unexpected sign out'),
                selected: false,
                autofocus: false,
              ),
            ],
          ),
        ),
      ),
      textScale: 1.3,
    );
    await tester.pumpAndSettle();
    final rail = find.byKey(const ValueKey('catalog-navigation-rail'));
    final avatar = find.byType(AppAvatar);
    final baseline = tester.getRect(find.text(label));
    void expectStableLayout() {
      final avatarRect = tester.getRect(avatar);
      expect(avatarRect.size, const Size.square(AppSizes.touchControl));
      expect(avatarRect.right, lessThanOrEqualTo(tester.getRect(rail).right));
      expect(tester.getRect(find.text(label)), baseline);
    }

    expectStableLayout();
    expanded.value = true;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 70));
    expectStableLayout();
    expanded.value = false;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expectStableLayout();
    await tester.pumpAndSettle();
    expectStableLayout();
    expect(tester.takeException(), isNull);
  });
}
