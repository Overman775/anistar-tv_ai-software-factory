import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';

import '../../../support/test_app.dart';

void main() {
  for (final variant in TvFocusTileVariant.values) {
    testWidgets('$variant focus preserves content bounds and paints a matching outline', (tester) async {
      final focus = FocusNode();
      addTearDown(focus.dispose);
      const contentKey = ValueKey('content');
      final content = find.byKey(contentKey);
      final settle = tester.pumpAndSettle;
      await pumpTvApp(
        tester,
        Center(
          child: SizedBox(
            width: 240,
            height: 120,
            child: TvFocusTile(
              variant: variant,
              focusNode: focus,
              onPressed: () => fail('Unexpected activation'),
              builder: (_, focused) => const ColoredBox(key: contentKey, color: Colors.black),
            ),
          ),
        ),
      );
      await settle();
      final before = tester.getSize(content);
      focus.requestFocus();
      await settle();
      final tile = find.byType(TvFocusTile);
      final scale = tester.widget<AnimatedScale>(find.descendant(of: tile, matching: find.byType(AnimatedScale)));
      final surface = tester.widget<AnimatedContainer>(
        find.descendant(of: tile, matching: find.byType(AnimatedContainer)),
      );
      final clip = tester.widget<ClipRRect>(find.descendant(of: tile, matching: find.byType(ClipRRect)));
      final outline = _focusDecoration(tester, tile);
      expect(scale.scale, variant == TvFocusTileVariant.card ? 1.025 : 1);
      expect(scale.duration, AppMotion.fast);
      expect(surface.duration, AppMotion.fast);
      expect(tester.getSize(content), before);
      expect(clip.borderRadius, outline.borderRadius);
      expect(outline.border, const Border.fromBorderSide(BorderSide(color: AppPalette.focusOutline, width: 2)));
      expect(_requireBoxDecoration(surface.decoration).boxShadow, isNotEmpty);
    });
  }

  testWidgets('reduced motion keeps the focus outline with no scale or transition', (tester) async {
    await pumpTvApp(
      tester,
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: TvFocusTile(
          autofocus: true,
          onPressed: () => fail('Unexpected activation'),
          builder: (_, focused) => const Text('Карточка'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final scale = tester.widget<AnimatedScale>(find.byType(AnimatedScale));
    final surface = tester.widget<AnimatedContainer>(find.byType(AnimatedContainer));
    expect(scale.scale, 1);
    expect(scale.duration, Duration.zero);
    expect(surface.duration, Duration.zero);
    expect(
      _focusDecoration(tester, find.byType(TvFocusTile)).border,
      const Border.fromBorderSide(BorderSide(color: AppPalette.focusOutline, width: 2)),
    );
  });

  testWidgets('selected row remains marked when focus moves to another row', (tester) async {
    final settle = tester.pumpAndSettle;
    final first = FocusNode();
    final second = FocusNode();
    addTearDown(first.dispose);
    addTearDown(second.dispose);
    await pumpTvApp(
      tester,
      Column(
        children: [
          TvChoiceTile(
            label: 'Текущая серия',
            selected: true,
            focusNode: first,
            autofocus: true,
            onPressed: () => fail('Unexpected activation'),
          ),
          TvChoiceTile(label: 'Другая серия', focusNode: second, onPressed: () => fail('Unexpected activation')),
        ],
      ),
    );
    await settle();
    second.requestFocus();
    await settle();
    final selected = find.ancestor(of: find.text('Текущая серия'), matching: find.byType(TvChoiceTile));
    final surface = tester.widget<AnimatedContainer>(
      find.descendant(of: selected, matching: find.byType(AnimatedContainer)),
    );
    expect(_requireBoxDecoration(surface.decoration).color, AppPalette.accentSubtle);
    expect(find.descendant(of: selected, matching: find.byType(AppIcon)), findsOneWidget);
    expect(second.hasFocus, isTrue);
    expect(tester.widgetList<AnimatedScale>(find.byType(AnimatedScale)).every((scale) => scale.scale == 1), isTrue);
  });

  testWidgets('short OK long OK and touch dispatch each action once', (tester) async {
    final settle = tester.pumpAndSettle;
    final keyDown = tester.sendKeyDownEvent;
    final keyUp = tester.sendKeyUpEvent;
    final keyRepeat = tester.sendKeyRepeatEvent;
    final choice = find.text('Выбор');
    var short = 0;
    var long = 0;
    final changes = <bool>[];
    await pumpTvApp(
      tester,
      Center(
        child: TvFocusTile(
          autofocus: true,
          onPressed: () => short++,
          onLongPressed: () => long++,
          onFocusChanged: changes.add,
          builder: (_, focused) => const SizedBox(width: 200, height: 100, child: Text('Выбор')),
        ),
      ),
    );
    await settle();
    await keyDown(LogicalKeyboardKey.select);
    expect(short, 0);
    await keyUp(LogicalKeyboardKey.select);
    await keyDown(LogicalKeyboardKey.select);
    await keyRepeat(LogicalKeyboardKey.select);
    await keyRepeat(LogicalKeyboardKey.select);
    await keyUp(LogicalKeyboardKey.select);
    await tester.tap(choice);
    await tester.longPress(choice);
    expect(short, 2);
    expect(long, 2);
    expect(changes, contains(true));
    FocusManager.instance.primaryFocus?.unfocus();
    await settle();
    expect(changes.last, isFalse);
  });

  testWidgets('poster placeholder and both Hero endpoints retain the card contour', (tester) async {
    await pumpTvApp(
      tester,
      const Row(
        children: [
          SizedBox(
            width: 200,
            height: 300,
            child: TvPosterHero(tag: 'source', imageUrl: null, semanticLabel: 'Постер'),
          ),
          SizedBox(
            width: 240,
            height: 360,
            child: TvPosterHero(tag: 'destination', imageUrl: null, semanticLabel: 'Постер'),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    final heroes = tester.widgetList<Hero>(find.byType(Hero));
    expect(
      heroes.every((hero) => hero.child is ClipRRect && (hero.child as ClipRRect).borderRadius == AppRadii.large),
      isTrue,
    );
    expect(find.byType(AppNetworkImage), findsNWidgets(2));
    expect(find.byType(Image), findsNothing);
    for (final hero in heroes) {
      final element = tester.element(find.byWidget(hero));
      final flight = hero.flightShuttleBuilder ?? (throw StateError('Missing Hero flight builder'));
      final shuttle = flight(element, const AlwaysStoppedAnimation(0.5), HeroFlightDirection.push, element, element);
      expect(shuttle, isA<ClipRRect>().having((clip) => clip.borderRadius, 'flight contour', AppRadii.large));
    }
    expect(tester.takeException(), isNull);
  });
}

BoxDecoration _requireBoxDecoration(Decoration? decoration) => switch (decoration) {
  final BoxDecoration box => box,
  _ => throw StateError('Expected a non-null BoxDecoration'),
};

BoxDecoration _focusDecoration(WidgetTester tester, Finder tile) {
  final painted = tester.widgetList<DecoratedBox>(find.descendant(of: tile, matching: find.byType(DecoratedBox)));

  return painted
      .where((box) => box.position == DecorationPosition.foreground)
      .map((box) => _requireBoxDecoration(box.decoration))
      .singleWhere((decoration) => decoration.border != null);
}
