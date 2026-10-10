import 'package:anistar_tv/packages/features/anime/domain/models/anime_episode.dart';
import 'package:anistar_tv/packages/features/anime/presentation/widgets/episode_card.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../../support/test_app.dart';

void main() {
  testWidgets('only watched episodes show a check; the semantic label includes status', (tester) async {
    final check = find.byIcon(Icons.check_circle_rounded);
    Widget card({bool watched = false, bool siteWatched = false}) => SizedBox(
      width: 360,
      height: 220,
      child: EpisodeCard(
        episode: AnimeEpisode(number: 1, title: 'Серия 1', isWatched: siteWatched),
        isWatched: watched,
        onTap: () => fail('No tap expected'),
      ),
    );
    await pumpTvApp(tester, card());
    expect(check, findsNothing);
    await pumpTvApp(tester, card(watched: true));
    expect(check, findsOneWidget);
    expect(
      find.byWidgetPredicate((widget) => widget is Semantics && widget.properties.label == 'Серия 1, просмотрена'),
      findsOneWidget,
    );
    await pumpTvApp(tester, card(siteWatched: true));
    // Recheck the independently supplied HTML mark after replacing local status.
    // ignore: avoid-duplicate-test-assertions
    expect(check, findsOneWidget);
  });
}
