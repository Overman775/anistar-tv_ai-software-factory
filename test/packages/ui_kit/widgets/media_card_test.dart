import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';

import '../../../support/test_app.dart';

void main() {
  for (final (variant, ratio) in [
    (MediaCardVariant.poster, 2 / 3),
    (MediaCardVariant.landscape, 219 / 92),
    (MediaCardVariant.episode, 16 / 9),
  ]) {
    testWidgets('$variant keeps its media geometry with an absent image', (tester) async {
      const label = 'Очень длинное название аниме, доступное целиком для чтения';
      final semantics = tester.ensureSemantics();

      await pumpMobileApp(
        tester,
        Center(
          child: SizedBox(
            width: 240,
            child: MediaCard(
              label: label,
              variant: variant,
              caption: 'Серия 1',
              heroTag: 'poster',
              onPressed: () => fail('Unexpected activation'),
            ),
          ),
        ),
        textScale: 1.5,
        disableAnimations: true,
      );
      await tester.pumpAndSettle();
      final image = find.byType(AppNetworkImage);
      final mediaSize = tester.getSize(image);
      expect(mediaSize.width / mediaSize.height, closeTo(ratio, 0.001));
      expect(find.byType(Image), findsNothing);
      expect(find.bySemanticsLabel('$label, Серия 1'), findsOneWidget);
      expect(find.byType(Hero), variant == MediaCardVariant.poster ? findsOneWidget : findsNothing);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    });
  }

  for (final heroTag in [null, 'poster-hero']) {
    for (final fit in [null, BoxFit.contain]) {
      testWidgets('poster preserves fit=$fit with heroTag=$heroTag', (tester) async {
        await pumpMobileApp(
          tester,
          Center(
            child: SizedBox(
              width: 200,
              child: MediaCard(
                label: 'Постер',
                fit: fit,
                heroTag: heroTag,
                onPressed: () => fail('Unexpected activation'),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final expected = fit ?? BoxFit.cover;
        expect(tester.widget<AppNetworkImage>(find.byType(AppNetworkImage)).fit, expected);
        if (heroTag != null) {
          expect(tester.widget<TvPosterHero>(find.byType(TvPosterHero)).fit, expected);
        }
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('selected media retains its state when focus moves and pressed state is distinct', (tester) async {
    final settle = tester.pumpAndSettle;
    final container = tester.widget<AnimatedContainer>;
    final first = FocusNode();
    final second = FocusNode();
    addTearDown(first.dispose);
    addTearDown(second.dispose);
    await pumpTvApp(
      tester,
      Row(
        children: [
          SizedBox(
            width: 200,
            child: MediaCard(
              label: 'Выбрано',
              selected: true,
              focusNode: first,
              autofocus: true,
              onPressed: () => fail('Unexpected activation'),
            ),
          ),
          SizedBox(
            width: 200,
            child: MediaCard(label: 'Другое', focusNode: second, onPressed: () => fail('Unexpected activation')),
          ),
        ],
      ),
    );
    await settle();
    final card = find.byType(MediaCard).first;
    final surface = find.descendant(of: card, matching: find.byType(AnimatedContainer));
    final focused = container(surface).decoration;
    final gesture = await tester.startGesture(tester.getCenter(card));
    await tester.pump();
    final pressed = container(surface).decoration;
    await gesture.cancel();
    second.requestFocus();
    await settle();
    final selected = container(surface).decoration;
    expect(focused, isNot(pressed));
    expect(selected, isNot(focused));
    expect(tester.widget<TvFocusTile>(find.descendant(of: card, matching: find.byType(TvFocusTile))).selected, isTrue);
    expect(tester.takeException(), isNull);
  });
}
