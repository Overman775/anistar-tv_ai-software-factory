import 'package:anistar_tv/packages/features/catalog/domain/models/anime_summary.dart';
import 'package:anistar_tv/packages/features/catalog/presentation/mobile/mobile_anime_card.dart';
import 'package:anistar_tv/packages/features/catalog/presentation/widgets/anime_card.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';

void main() {
  testWidgets('nullable poster retains TV and mobile placeholders Hero and actions', (tester) async {
    const anime = AnimeSummary(id: 1, slug: '1-anime', title: 'Anime');
    var taps = 0;
    for (final mobile in [false, true]) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 220,
              height: 330,
              child: mobile
                  ? MobileAnimeCard(anime: anime, onTap: () => taps++, onActions: () => taps++)
                  : AnimeCard(anime: anime, autofocus: true, onTap: () => taps++),
            ),
          ),
        ),
      );
      final hero = tester.widget<TvPosterHero>(find.byType(TvPosterHero));
      expect(hero.imageUrl, isNull);
      expect(hero.tag, 'anime-poster-1');
      expect(find.byType(Image), findsNothing);
      if (mobile) {
        await tester.tap(find.text('Anime'));
      } else {
        await tester.sendKeyEvent(LogicalKeyboardKey.select);
      }
      expect(taps, mobile ? 2 : 1);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('TV card delegates short and held OK to separate actions', (tester) async {
    var opens = 0;
    var actions = 0;
    final focusChanges = <bool>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 220,
            height: 330,
            child: AnimeCard(
              anime: const AnimeSummary(id: 1, slug: 'anime', title: 'Anime'),
              autofocus: true,
              onTap: () => opens++,
              onLongPressed: () => actions++,
              onFocusChanged: focusChanges.add,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(TvFocusTile), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.select);
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.select);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.select);
    expect(opens, 1);
    expect(actions, 1);
    expect(focusChanges, contains(true));
  });

  testWidgets('mobile poster tap and long press each activate exactly once', (tester) async {
    var opens = 0;
    var actions = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 220,
            height: 330,
            child: MobileAnimeCard(
              anime: const AnimeSummary(id: 1, slug: 'anime', title: 'Anime', isFavorite: true),
              onTap: () => opens++,
              onActions: () => actions++,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final poster = find.byType(TvPosterHero);
    await tester.tap(poster);
    await tester.longPress(poster);
    expect(opens, 1);
    expect(actions, 1);
    expect(find.byIcon(Icons.star_rounded), findsOneWidget);
    expect(find.byType(TvFocusTile), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders catalog metadata and opens the selected anime', (tester) async {
    var taps = 0;
    final anime = AnimeSummary(
      id: 1,
      slug: '1-anime',
      title: 'Красивое аниме',
      year: '2026',
      rating: 8.4,
      posterUri: Uri(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 220,
            height: 330,
            child: AnimeCard(anime: anime, autofocus: true, onTap: () => taps++),
          ),
        ),
      ),
    );

    expect(find.text('Красивое аниме'), findsOneWidget);
    expect(find.text('2026'), findsOneWidget);
    expect(find.text('8,4'), findsOneWidget);
    expect(find.byIcon(Icons.grade_rounded), findsOneWidget);
    expect(find.byIcon(Icons.play_arrow_rounded), findsNothing);
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    expect(taps, 1);
  });
}
