import 'package:anistar_tv/packages/features/catalog/domain/models/anime_summary.dart';
import 'package:anistar_tv/packages/features/catalog/presentation/widgets/anime_card.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('renders catalog metadata and opens the selected anime', (tester) async {
    var taps = 0;
    final anime = AnimeSummary(id: 1, slug: '1-anime', title: 'Красивое аниме', year: '2026', posterUri: Uri());

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
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    expect(taps, 1);
  });
}
