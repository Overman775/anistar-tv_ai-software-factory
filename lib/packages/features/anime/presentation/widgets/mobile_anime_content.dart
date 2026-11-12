import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';

import '../../domain/models/anime_episode.dart';
import '../../domain/models/anime_screen_data.dart';
import 'anime_hero.dart';
import 'episode_card.dart';

/// Touch composition shares route disclosure and selection with the TV profile.
class MobileAnimeContent extends StatelessWidget {
  const MobileAnimeContent({
    required this.data,
    required this.watched,
    required this.onEpisodeTap,
    required this.onRefresh,
    required this.controller,
    required this.expanded,
    required this.onToggleDetails,
    required this.disclosure,
    this.selectedEpisode,
    this.favoriteAction,
    super.key,
  });

  final AnimeScreenData data;
  List<AnimeEpisode> get episodes => data.episodes;
  final Set<int> watched;
  final bool expanded;
  final VoidCallback onToggleDetails;
  final int? selectedEpisode;
  final AnimeDisclosure disclosure;
  Widget? get filterActions => expanded ? disclosure.child.metadata : null;
  final Widget? favoriteAction;
  final ValueChanged<AnimeEpisode> onEpisodeTap;
  final Future<void> Function() onRefresh;
  final ScrollController controller;

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    key: const ValueKey('mobile-anime-refresh'),
    onRefresh: onRefresh,
    child: ListView(
      controller: controller,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        AppLayoutScope.horizontalPaddingOf(context),
        12,
        AppLayoutScope.horizontalPaddingOf(context),
        32 + MediaQuery.paddingOf(context).bottom,
      ),
      children: [
        Semantics(header: true, child: Text(data.details.title, style: AppContentTypography.detailTitleOf(context))),
        const SizedBox(height: AppSpacing.lg),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            Semantics(
              expanded: expanded,
              child: AppButton(
                label: 'Подробнее',
                variant: AppButtonVariant.neutral,
                icon: RotatedBox(
                  quarterTurns: expanded ? 3 : 1,
                  child: const AppIcon(AppIconType.chevronRight, size: 20),
                ),
                onPressed: onToggleDetails,
              ),
            ),
            ?favoriteAction,
          ],
        ),
        disclosure,
        const SizedBox(height: AppSpacing.xl),
        AppSectionHeader(title: 'Серии', titleStyle: AppContentTypography.sectionTitleOf(context)),
        const SizedBox(height: AppSpacing.md),
        for (final episode in episodes)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: EpisodeCard(
              key: ValueKey('mobile-episode-${episode.number}'),
              episode: episode,
              episodeHeight: 92,
              selected: selectedEpisode == episode.number,
              isWatched: watched.contains(episode.number),
              onTap: () => onEpisodeTap(episode),
            ),
          ),
      ],
    ),
  );
}
