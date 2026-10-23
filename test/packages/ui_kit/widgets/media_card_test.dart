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
              onPressed: _unexpectedActivation,
            ),
          ),
        ),
        textScale: 1.5,
        disableAnimations: true,
      );
      await tester.pumpAndSettle();
      final image = find.byType(AppNetworkImage);
      final mediaSize = tester.getSize(image);
      if (variant == MediaCardVariant.episode) {
        expect(mediaSize.height, greaterThanOrEqualTo(mediaSize.width / ratio));
      } else {
        expect(mediaSize.width / mediaSize.height, closeTo(ratio, 0.001));
      }
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
              child: MediaCard(label: 'Постер', fit: fit, heroTag: heroTag, onPressed: _unexpectedActivation),
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
              onPressed: _unexpectedActivation,
            ),
          ),
          SizedBox(
            width: 200,
            child: MediaCard(label: 'Другое', focusNode: second, onPressed: _unexpectedActivation),
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

  testWidgets('episode card keeps its caption and omits a trailing play affordance by default', (tester) async {
    const label = 'Серия 8';
    const caption = 'Очень длинное собственное название серии';
    final semantics = tester.ensureSemantics();

    await pumpMobileApp(
      tester,
      const Center(
        child: SizedBox(
          width: 240,
          child: MediaCard(
            label: label,
            caption: caption,
            variant: MediaCardVariant.episode,
            onPressed: _unexpectedActivation,
          ),
        ),
      ),
      disableAnimations: true,
    );
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('$label, $caption'), findsOneWidget);
    expect(tester.widget<MediaCard>(find.byType(MediaCard)).showEpisodeTrailing, isFalse);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('episode card exposes a trailing affordance only when requested', (tester) async {
    await pumpMobileApp(
      tester,
      const Center(
        child: SizedBox(
          width: 240,
          child: MediaCard(
            label: 'Серия 8',
            caption: 'Название',
            variant: MediaCardVariant.episode,
            showEpisodeTrailing: true,
            trailing: Text('Открыть'),
            onPressed: _unexpectedActivation,
          ),
        ),
      ),
      disableAnimations: true,
    );
    await tester.pumpAndSettle();

    expect(find.text('Открыть'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('episode card uses its width geometry by default and an explicit compact baseline when provided', (
    tester,
  ) async {
    Future<Size> mount(double? episodeHeight) async {
      await pumpMobileApp(
        tester,
        Center(
          child: SizedBox(width: 360, child: _MediaCardTest(episodeHeight: episodeHeight)),
        ),
        disableAnimations: true,
      );
      await tester.pumpAndSettle();

      return tester.getSize(find.byType(MediaCard));
    }

    final defaultGeometry = await mount(null);
    final compactBaseline = await mount(92);

    expect(defaultGeometry.height, closeTo(360 / AppSizes.landscapeRatio, 0.001));
    expect(compactBaseline.height, 92);
    expect(tester.takeException(), isNull);
  });

  testWidgets('episode card grows beyond its explicit baseline for long text at 200 percent scale', (tester) async {
    Future<Size> mount({required String caption, required double textScale}) async {
      await pumpMobileApp(
        tester,
        Center(
          child: SizedBox(
            width: 360,
            child: MediaCard(
              label: 'Серия 123',
              caption: caption,
              episodeHeight: 92,
              variant: MediaCardVariant.episode,
              onPressed: _unexpectedActivation,
            ),
          ),
        ),
        textScale: textScale,
        disableAnimations: true,
      );
      await tester.pumpAndSettle();

      return tester.getSize(find.byType(MediaCard));
    }

    final compact = await mount(caption: 'Короткое название', textScale: 1);
    final expanded = await mount(
      caption: 'Длинное собственное название серии, которое должно оставаться доступным при крупном тексте',
      textScale: 2,
    );

    expect(compact.height, greaterThanOrEqualTo(92));
    expect(expanded.height, greaterThan(compact.height));
    expect(expanded.height, greaterThan(92));
    expect(
      find.bySemanticsLabel(
        'Серия 123, Длинное собственное название серии, которое должно оставаться доступным при крупном тексте',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('confirmed bookmark is passive and card activation remains singular', (tester) async {
    final settle = tester.pumpAndSettle;
    var activations = 0;
    final semantics = tester.ensureSemantics();
    await pumpMobileApp(
      tester,
      Center(
        child: SizedBox(
          width: 180,
          child: MediaCard(label: 'Избранное аниме', showBookmark: true, onPressed: () => activations++),
        ),
      ),
      disableAnimations: true,
    );
    await settle();

    final bookmark = find.byType(MediaCardBookmark);
    final card = find.byType(MediaCard);
    final initialCard = tester.widget<MediaCard>(card);
    expect(bookmark, findsOneWidget);
    expect(initialCard.showBookmark, isTrue);
    expect(find.bySemanticsLabel('Избранное аниме'), findsOneWidget);
    await tester.tap(card);
    await settle();
    final activatedCard = tester.widget<MediaCard>(card);
    expect(activations, 1);
    expect(activatedCard.showBookmark, isTrue);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('mobile card can hide its year caption while retaining the caller rating badge', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpMobileApp(
      tester,
      const Center(
        child: SizedBox(
          width: 180,
          child: MediaCard(
            label: 'Аниме без года',
            caption: '2026',
            showCaption: false,
            badges: [Text('★ 8,7')],
            onPressed: _unexpectedActivation,
          ),
        ),
      ),
      disableAnimations: true,
    );
    await tester.pumpAndSettle();

    expect(find.text('2026'), findsNothing);
    expect(find.text('★ 8,7'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('Аниме без года')), findsOneWidget);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });
}

void _unexpectedActivation() => fail('Unexpected activation');

class _MediaCardTest extends StatelessWidget {
  const _MediaCardTest({this.episodeHeight});

  final double? episodeHeight;

  @override
  Widget build(BuildContext context) => MediaCard(
    label: 'Серия 1',
    showCaption: false,
    episodeHeight: episodeHeight,
    variant: MediaCardVariant.episode,
    onPressed: _unexpectedActivation,
  );
}
