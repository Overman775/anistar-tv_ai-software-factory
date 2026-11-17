import 'dart:ui' show Tristate;

import 'package:anistar_tv/packages/features/anime/presentation/widgets/anime_filter_chip.dart';
import 'package:anistar_tv/packages/features/catalog/domain/models/catalog_filter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';

import '../../../support/test_app.dart';

void main() {
  for (final mobile in [false, true]) {
    testWidgets('short Li chip keeps horizontal touch target across rotation mobile=$mobile', (tester) async {
      const filter = CatalogFilter(label: 'Li', path: '/li');
      final nodes = <String, FocusNode>{};
      addTearDown(() {
        for (final node in nodes.values) {
          node.dispose();
        }
      });
      var calls = 0;
      final focusChanges = <bool>[];
      final child = Center(
        child: AnimeFilterChip(
          filter: filter,
          label: filter.label,
          focusNodes: nodes,
          index: 0,
          maxWidth: 200,
          onSelected: (_) => calls++,
          onFocused: (_, _, focused) => focusChanges.add(focused),
        ),
      );
      if (mobile) {
        await pumpMobileApp(tester, child);
      } else {
        await pumpTvApp(tester, child);
      }
      Future<double> verify() async {
        final target = tester.getRect(find.byType(AnimeFilterChip));
        final visual = tester.getRect(find.byType(AppFocusBorder));
        expect(target.width, greaterThanOrEqualTo(48));
        if (!mobile) expect(visual.width, lessThan(target.width));
        final previous = calls;
        final point = mobile ? Offset(target.center.dx, target.top + 0.5) : Offset(target.left + 0.5, target.center.dy);
        expect(visual.contains(point), isFalse);
        await tester.tapAt(point);
        await tester.pumpAndSettle();
        expect(calls, previous + 1);
        return visual.width;
      }

      final originalWidth = await verify();
      if (mobile) {
        tester.view.physicalSize = const Size(844, 390);
        await tester.pumpAndSettle();
        expect(await verify(), closeTo(originalWidth, 0.01));
      }
      expect(tester.takeException(), isNull);
    });
  }
  for (final mobile in [false, true]) {
    testWidgets('anime filter chip exposes its complete 48dp target mobile=$mobile', (tester) async {
      const filter = CatalogFilter(label: 'Жанр', path: '/genre');
      final nodes = <String, FocusNode>{};
      addTearDown(() {
        for (final node in nodes.values) {
          node.dispose();
        }
      });
      var calls = 0;
      final focusChanges = <bool>[];
      final child = Center(
        child: AnimeFilterChip(
          filter: filter,
          label: filter.label,
          focusNodes: nodes,
          index: 0,
          maxWidth: 200,
          onSelected: (_) => calls++,
          onFocused: (_, _, focused) => focusChanges.add(focused),
        ),
      );
      if (mobile) {
        await pumpMobileApp(tester, child);
      } else {
        await pumpTvApp(tester, child);
      }
      final target = tester.getRect(find.byType(AnimeFilterChip));
      final visual = tester.getSize(find.byType(AppFocusBorder)).height;
      expect(target.height, greaterThanOrEqualTo(48));
      expect(target.width, greaterThanOrEqualTo(48));
      expect(visual, mobile ? 36 : inInclusiveRange(36, 48));
      await tester.tapAt(target.topCenter + const Offset(0, 1));
      await tester.pump();
      expect(calls, 1);
      expect(tester.takeException(), isNull);
    });
  }
  for (final profile in AppDeviceProfile.values) {
    testWidgets(
      '$profile metadata actions preserve visual and touch bounds at ${profile == AppDeviceProfile.tv ? '130%' : '200%'} text',
      (tester) async {
        final focus = FocusNode();
        addTearDown(focus.dispose);
        final semantics = tester.ensureSemantics();
        var taps = 0;
        final content = Center(
          child: Wrap(
            spacing: 8,
            children: [
              AppButton(label: 'Жанр', variant: AppButtonVariant.metadata, focusNode: focus, onPressed: () => taps++),
              AppButton(
                label: 'Год',
                variant: AppButtonVariant.metadata,
                enabled: false,
                onPressed: () => fail('A disabled control activated'),
              ),
            ],
          ),
        );

        if (profile == AppDeviceProfile.tv) {
          await pumpTvApp(tester, content, textScale: 1.3, disableAnimations: true);
        } else {
          await pumpMobileApp(tester, content, textScale: 2, disableAnimations: true);
        }

        final actions = find.byType(AppButton);
        final genre = actions.first;
        final year = actions.last;
        final frames = find.byType(AppFocusBorder);
        final genreBounds = tester.getRect(genre);
        expect(genreBounds.height, greaterThanOrEqualTo(48));
        expect(tester.getSize(frames.first).height, greaterThan(36));
        expect(tester.getRect(year).left - genreBounds.right, 8);
        expect(
          tester.getSemantics(find.bySemanticsLabel('Год')).getSemanticsData().flagsCollection.isEnabled,
          Tristate.isFalse,
        );
        semantics.dispose();
        focus.requestFocus();
        await tester.pump();
        expect(tester.getRect(genre), genreBounds);
        expect(tester.widget<AppFocusBorder>(frames.first).focused, isTrue);
        await tester.tap(genre);
        await tester.tap(year);
        expect(taps, 1);
        expect(tester.takeException(), isNull);
      },
    );
    testWidgets('$profile retains semantic selection while focus moves to another choice', (tester) async {
      final choiceFocus = FocusNode();
      final otherFocus = FocusNode();
      addTearDown(choiceFocus.dispose);
      addTearDown(otherFocus.dispose);
      final semantics = tester.ensureSemantics();
      final content = Center(
        child: SizedBox(
          width: 280,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TvChoiceTile(
                label: 'Текущая серия',
                selected: true,
                focusNode: choiceFocus,
                onPressed: () => fail('Unexpected activation'),
              ),
              TvChoiceTile(
                label: 'Другая серия',
                focusNode: otherFocus,
                onPressed: () => fail('Unexpected activation'),
              ),
            ],
          ),
        ),
      );
      if (profile == AppDeviceProfile.tv) {
        await pumpTvApp(tester, content, textScale: 1.3, disableAnimations: true);
      } else {
        await pumpMobileApp(tester, content, textScale: 2, disableAnimations: true);
      }

      choiceFocus.requestFocus();
      await tester.pump();
      final selectedChoice = find.bySemanticsLabel('Текущая серия');
      final bounds = tester.getRect(find.byType(TvChoiceTile).first);
      expect(tester.getSemantics(selectedChoice).getSemanticsData().flagsCollection.isFocused, Tristate.isTrue);
      otherFocus.requestFocus();
      await tester.pumpAndSettle();
      expect(otherFocus.hasPrimaryFocus, isTrue);
      final selectedFlags = tester.getSemantics(selectedChoice).getSemanticsData().flagsCollection;
      expect(selectedFlags.isSelected, Tristate.isTrue);
      expect(selectedFlags.isFocused, Tristate.isFalse);
      expect(tester.getRect(find.byType(TvChoiceTile).first), bounds);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    });
  }

  testWidgets('a compact metadata surface leaves the whole touch target usable', (tester) async {
    var taps = 0;
    await pumpMobileApp(
      tester,
      Center(
        child: AppButton(label: 'Год', variant: AppButtonVariant.metadata, onPressed: () => taps++),
      ),
      disableAnimations: true,
    );
    final target = tester.getRect(find.byType(AppButton));
    expect(target.height, 48);
    expect(target.width, greaterThanOrEqualTo(48));
    expect(tester.getSize(find.byType(AppFocusBorder)).height, 36);
    await tester.tapAt(target.topCenter + const Offset(0, 2));
    expect(taps, 1);
  });
}
