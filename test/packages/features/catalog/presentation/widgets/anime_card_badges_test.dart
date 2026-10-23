// Each finder observes a distinct pump or semantic assertion.
// ignore_for_file: prefer-moving-to-variable

import 'package:anistar_tv/packages/features/catalog/domain/models/anime_summary.dart';
import 'package:anistar_tv/packages/features/catalog/presentation/mobile/mobile_anime_card.dart';
import 'package:anistar_tv/packages/features/catalog/presentation/widgets/anime_card.dart';
import 'package:anistar_tv/packages/features/catalog/presentation/widgets/anime_rating_badge.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';

import '../../../../../support/test_app.dart';

void main() {
  for (final (rating, label) in [(0.0, '0,0'), (8.7, '8,7'), (8.74, '8,7'), (10.0, '10,0')]) {
    testWidgets('rating $rating retains source scale and announces full meaning', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpTvApp(tester, AnimeRatingBadge(rating: rating));
      expect(find.text(label), findsOneWidget);
      expect(find.textContaining('/10'), findsNothing);
      final node = tester.getSemantics(find.byType(AppMetadataBadge));
      expect(node.label, 'Рейтинг $label из 10');
      expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isFalse);
      expect(node.getSemanticsData().hasAction(SemanticsAction.longPress), isFalse);
      expect(find.descendant(of: find.byType(AppMetadataBadge), matching: find.byType(Focus)), findsNothing);
      semantics.dispose();
    });
  }

  for (final rating in [null, double.nan, double.infinity, double.negativeInfinity, -0.1, 10.1]) {
    testWidgets('invalid or absent rating $rating never creates a false zero', (tester) async {
      await pumpTvApp(tester, AnimeRatingBadge(rating: rating));
      expect(find.byType(AppMetadataBadge), findsNothing);
      expect(
        find.byWidgetPredicate((widget) => widget is AppMetadataBadge && widget.icon == Icons.grade_rounded),
        findsNothing,
      );
      expect(find.text('0,0'), findsNothing);
    });
  }

  for (final mobile in [false, true]) {
    for (final (source, override, visible) in [
      (true, null, true),
      (false, null, false),
      (null, null, false),
      (true, false, false),
      (false, true, true),
      (null, true, true),
    ]) {
      testWidgets('favorite source=$source override=$override mobile=$mobile', (tester) async {
        final semantics = tester.ensureSemantics();
        final anime = AnimeSummary(id: 1, slug: 'anime', title: 'Anime', isFavorite: source, rating: 8.7);
        if (mobile) {
          await pumpMobileApp(tester, _AnimeCardBadgesTest(mobile: true, anime: anime, favorite: override));
        } else {
          await pumpTvApp(tester, _AnimeCardBadgesTest(mobile: false, anime: anime, favorite: override));
        }
        await tester.pumpAndSettle();
        expect(find.byType(MediaCardBookmark), visible ? findsOneWidget : findsNothing);
        expect(find.text('8,7'), mobile ? findsNothing : findsOneWidget);
        expect(find.byType(TvFocusTile), findsOneWidget);
        final badges = tester.widgetList<AppMetadataBadge>(find.byType(AppMetadataBadge));
        if (mobile) {
          expect(badges.map((badge) => badge.semanticLabel), isNot(contains('Рейтинг 8,7 из 10')));
        } else {
          expect(badges.map((badge) => badge.semanticLabel), contains('Рейтинг 8,7 из 10'));
        }
        for (final element in find.byType(AppMetadataBadge).evaluate()) {
          final badge = find.byElementPredicate((candidate) => identical(candidate, element));
          final metadataSemantics = tester.widget<Semantics>(
            find.descendant(of: badge, matching: find.byType(Semantics)).first,
          );
          expect(metadataSemantics.properties.onTap, isNull);
          expect(metadataSemantics.properties.onLongPress, isNull);
          expect(find.descendant(of: badge, matching: find.byType(Focus)), findsNothing);
        }
        semantics.dispose();
      });
    }

    for (final scale in [1.0, 1.3, 2.0]) {
      testWidgets('long title and both badges fit mobile=$mobile text=$scale', (tester) async {
        final semantics = tester.ensureSemantics();
        const anime = AnimeSummary(
          id: 1,
          slug: 'anime',
          title: 'Очень длинное название аниме о путешествии в другой мир и возвращении домой',
          year: '2026',
          isFavorite: true,
          rating: 10,
        );
        final card = MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(scale)),
          child: _AnimeCardBadgesTest(mobile: mobile, anime: anime),
        );
        if (mobile) {
          await pumpMobileApp(tester, card, size: const Size(320, 740), textScale: scale);
        } else {
          await pumpTvApp(tester, card);
        }
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text(anime.title), findsOneWidget);
        final title = tester.widget<Text>(find.text(anime.title));
        expect(title.style?.fontSize, 15);
        expect(find.text('2026'), mobile ? findsNothing : findsOneWidget);
        expect(MediaQuery.textScalerOf(tester.element(find.text(anime.title))).scale(15), closeTo(scale * 15, 0.001));
        expect(find.bySemanticsLabel(RegExp(anime.title)), findsWidgets);
        expect(find.text('10,0'), mobile ? findsNothing : findsOneWidget);
        if (!mobile) {
          final favoriteRect = tester.getRect(find.byType(MediaCardBookmark));
          final ratingRect = tester.getRect(find.byType(AnimeRatingBadge));
          expect(favoriteRect.overlaps(ratingRect), isFalse);
          expect(tester.getRect(find.byKey(const ValueKey('card-bounds'))).contains(ratingRect.center), isTrue);
        }
        semantics.dispose();
      });
    }
  }
}

class _AnimeCardBadgesTest extends StatelessWidget {
  const _AnimeCardBadgesTest({required this.mobile, required this.anime, this.favorite});

  final bool mobile;
  final AnimeSummary anime;
  final bool? favorite;

  @override
  Widget build(BuildContext context) => Center(
    child: SizedBox(
      key: const ValueKey('card-bounds'),
      width: mobile ? 150 : 220,
      height: mobile ? 340 : 330,
      child: mobile
          ? MobileAnimeCard(
              anime: anime,
              isFavorite: favorite,
              onTap: () => fail('Unexpected activation'),
              onActions: () => fail('Unexpected actions'),
            )
          : AnimeCard(anime: anime, isFavorite: favorite, onTap: () => fail('Unexpected activation')),
    ),
  );
}
