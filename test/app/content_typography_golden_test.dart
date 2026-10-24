import 'package:anistar_tv/packages/features/anime/domain/models/anime_episode.dart';
import 'package:anistar_tv/packages/features/anime/presentation/widgets/episode_card.dart';
import 'package:anistar_tv/packages/features/catalog/domain/models/anime_summary.dart';
import 'package:anistar_tv/packages/features/catalog/presentation/mobile/mobile_anime_card.dart';
import 'package:anistar_tv/packages/features/catalog/presentation/widgets/anime_card.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../support/test_app.dart';

const _title = 'Очень длинное название о путешествии друзей через незнакомые города и возвращении домой';
const _anime = AnimeSummary(id: 1, slug: 'long', title: _title, year: '2026', rating: 8.7, isFavorite: true);
const _episode = AnimeEpisode(number: 7, title: _title, isWatched: true);

void main() {
  for (final mobile in [false, true]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('long catalog favorite and episode typography mobile=$mobile scale=$scale', (tester) async {
        final child = Padding(
          padding: const EdgeInsets.all(24),
          child: ListView(
            children: [
              Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: mobile ? 150 : 220,
                  height: mobile ? 340 : 330,
                  child: mobile
                      ? const MobileAnimeCard(anime: _anime, onTap: _unexpected, onActions: _unexpected)
                      : const AnimeCard(anime: _anime, onTap: _unexpected),
                ),
              ),
              const SizedBox(height: 24),
              if (mobile)
                const EpisodeCard(episode: _episode, isWatched: true, episodeHeight: 92, onTap: _unexpected)
              else
                const Align(
                  alignment: Alignment.topLeft,
                  child: SizedBox(
                    width: 360,
                    height: 220,
                    child: EpisodeCard(episode: _episode, onTap: _unexpected),
                  ),
                ),
            ],
          ),
        );
        if (mobile) {
          await pumpMobileApp(tester, child, textScale: scale, disableAnimations: true);
        } else {
          await pumpTvApp(tester, child, size: wideTvSize, textScale: scale, disableAnimations: true);
        }
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(
            'goldens/content_typography_${mobile ? 'mobile' : 'tv'}_${scale == 1 ? 'normal' : 'scaled'}.png',
          ),
        );
      }, tags: ['golden']);
    }
  }
}

void _unexpected() => fail('Unexpected activation during typography comparison');
