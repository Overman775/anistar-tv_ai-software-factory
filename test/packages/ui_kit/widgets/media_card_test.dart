import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
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
    expect(find.bySemanticsLabel('Избранное аниме, В избранном'), findsOneWidget);
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

  for (final profile in AppDeviceProfile.values) {
    testWidgets('$profile poster metadata belongs to the single card activation target', (tester) async {
      final semantics = tester.ensureSemantics();
      final focus = FocusNode();
      addTearDown(focus.dispose);
      var calls = 0;
      final content = Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 140,
              child: MediaCard(
                label: 'Аниме',
                ratingLabel: '9,2',
                showBookmark: true,
                focusNode: focus,
                scaleOnFocus: false,
                onPressed: () => calls++,
              ),
            ),
            const SizedBox(
              width: 100,
              child: MediaCard(label: 'Без меток', onPressed: _unexpectedActivation),
            ),
          ],
        ),
      );
      if (profile == AppDeviceProfile.tv) {
        await pumpTvApp(tester, content);
      } else {
        await pumpMobileApp(tester, content);
      }
      await tester.pumpAndSettle();

      final card = find.byType(MediaCard).first;
      final bounds = tester.getRect(card);
      final badge = find.byType(AppMetadataBadge);
      final bookmark = find.byType(MediaCardBookmark);
      expect(badge, findsOneWidget);
      expect(bookmark, findsOneWidget);
      expect(tester.getTopLeft(badge) - bounds.topLeft, const Offset(8, 8));
      expect(tester.getTopLeft(bookmark).dy, bounds.top);
      final score = tester.widget<Text>(find.text('9,2'));
      expect(score.style?.fontSize, profile == AppDeviceProfile.tv ? 16 : 14);
      expect(find.textContaining('/ 10'), findsNothing);
      expect(find.bySemanticsLabel('Без меток'), findsOneWidget);
      final node = tester.getSemantics(find.bySemanticsLabel('Аниме, Рейтинг 9,2 из 10, В избранном'));
      expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
      node.owner?.performAction(node.id, SemanticsAction.tap);
      await tester.pumpAndSettle();
      expect(tester.getRect(card), bounds);
      expect(focus.hasFocus, isTrue);
      await tester.tapAt(tester.getCenter(bookmark));
      if (profile == AppDeviceProfile.tv) await tester.sendKeyEvent(LogicalKeyboardKey.select);
      expect(calls, profile == AppDeviceProfile.tv ? 3 : 2);
      semantics.dispose();
    });
  }

  for (final scale in [1.0, 2.0]) {
    testWidgets('104dp poster keeps rating, bookmark and title separate at text scale $scale', (tester) async {
      const title = 'Длинное название аниме для проверки подписи';
      final semantics = tester.ensureSemantics();
      var opens = 0;
      await pumpTvApp(
        tester,
        Center(
          child: SizedBox(
            width: 104,
            child: MediaCard(label: title, ratingLabel: '10,0', showBookmark: true, onPressed: () => opens++),
          ),
        ),
        textScale: scale,
        disableAnimations: true,
      );
      await tester.pumpAndSettle();
      final card = tester.getRect(find.byType(MediaCard));
      final badgeFinder = find.byType(AppMetadataBadge);
      final badge = tester.getRect(badgeFinder);
      final scoreFinder = find.text('10,0');
      final score = tester.getRect(scoreFinder);
      final scoreParagraph = tester.renderObject<RenderParagraph>(scoreFinder);
      final lastDigit = scoreParagraph.getBoxesForSelection(const TextSelection(baseOffset: 3, extentOffset: 4));
      final star = tester.getRect(find.descendant(of: badgeFinder, matching: find.byType(AppIcon)));
      final bookmark = tester.getRect(find.byType(MediaCardBookmark));
      final titleFinder = find.text(title);
      final caption = tester.getRect(titleFinder);
      expect(tester.widget<Text>(titleFinder).maxLines, scale == 2 ? 1 : 2);
      expect(MediaQuery.textScalerOf(tester.element(titleFinder)).scale(15), 15 * scale);
      expect(card.size, const Size(104, 156));
      expect(badge.topLeft - card.topLeft, const Offset(8, 8));
      expect(card.right - badge.right, greaterThanOrEqualTo(2));
      expect(scoreParagraph.didExceedMaxLines, isFalse);
      expect(lastDigit, hasLength(1));
      expect(score.left + lastDigit.single.right, lessThanOrEqualTo(badge.right));
      expect(MediaQuery.textScalerOf(tester.element(scoreFinder)).scale(16), 16 * scale);
      expect(badge.right - score.right, scale == 1 ? closeTo(8, 0.01) : inInclusiveRange(0, 7.99));
      if (star.left - badge.left < 7.99) expect(badge.right - score.right, closeTo(1, 0.01));
      expect(bookmark.size, const Size(36, 48));
      expect(card.right - bookmark.right, 16);
      expect(bookmark.top - badge.bottom, 4);
      expect(caption.top, greaterThanOrEqualTo(bookmark.bottom));
      expect(caption.bottom, lessThanOrEqualTo(card.bottom));
      final node = tester.getSemantics(find.bySemanticsLabel('$title, Рейтинг 10,0 из 10, В избранном'));
      node.owner?.performAction(node.id, SemanticsAction.tap);
      await tester.tapAt(bookmark.center);
      expect(opens, 2);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    });
  }

  testWidgets('episode selection and confirmed viewing use independent indicators', (tester) async {
    const repeated = EpisodeCaption(number: 7, title: '  сЕРИЯ   7  ');
    const empty = EpisodeCaption(number: 7, title: '  ');
    const descriptive = EpisodeCaption(number: 7, title: 'Начало пути');
    expect(repeated.descriptiveTitle, isNull);
    expect(empty.descriptiveTitle, isNull);
    expect(repeated.semanticLabel(isWatched: true), 'Серия 7, просмотрена');
    final semantics = tester.ensureSemantics();
    var opens = 0;
    await pumpTvApp(
      tester,
      Center(
        child: SizedBox(
          width: 300,
          child: MediaCard(
            label: descriptive.numberLabel,
            caption: descriptive.descriptiveTitle,
            variant: MediaCardVariant.episode,
            selected: true,
            isWatched: true,
            autofocus: true,
            onPressed: () => opens++,
          ),
        ),
      ),
      disableAnimations: true,
    );
    await tester.pumpAndSettle();
    expect(find.text('Серия 7'), findsOneWidget);
    expect(find.text('Начало пути'), findsOneWidget);
    expect(find.bySemanticsLabel('Серия 7, Начало пути, текущая, просмотрена'), findsOneWidget);
    final marks = tester
        .widgetList<AppIcon>(find.byType(AppIcon))
        .where((icon) => icon.color == AppPalette.primary || icon.color == AppPalette.success);
    expect(marks.map((icon) => icon.color), [AppPalette.primary, AppPalette.success]);
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    expect(opens, 1);
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
