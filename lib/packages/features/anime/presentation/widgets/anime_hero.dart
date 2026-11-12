import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';

import '../../domain/models/anime_screen_data.dart';
import 'anime_description.dart';
import 'anime_detail_filter_actions.dart';
import 'mobile_anime_poster_header.dart';

class AnimeHero extends StatelessWidget {
  const AnimeHero({required this.data, required this.metadata, this.fallbackPosterUri, this.watchOrder, super.key});

  final AnimeScreenData data;
  final AnimeDetailFilterActions metadata;
  final Widget? watchOrder;
  final Uri? fallbackPosterUri;

  @override
  Widget build(BuildContext context) {
    if (!AppLayoutScope.isTvOf(context)) return _content(context);

    final posterWidth = (MediaQuery.sizeOf(context).width * 0.22).clamp(140.0, 240.0);
    final requiredWidth = posterWidth + AppSpacing.xl + metadata.minimumWidthOf(context);
    final enlargedText = MediaQuery.textScalerOf(context).scale(16) > 16;

    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth;
        var inset = AppSpacing.xxl;
        if (enlargedText &&
            available < requiredWidth + AppSpacing.xxl * 2 &&
            available >= requiredWidth + AppSpacing.xl * 2) {
          inset = AppSpacing.xl;
        }
        return _content(
          context,
          inset: inset,
          tvPosterAndMetadata: _tvPosterAndMetadata(posterWidth, sideBySide: available >= requiredWidth + inset * 2),
        );
      },
    );
  }

  Widget _content(BuildContext context, {double inset = 0, Widget? tvPosterAndMetadata}) {
    final details = data.details;
    final theme = Theme.of(context).textTheme;
    final description = details.description?.trim();
    final publication = [details.updateMessage, details.publicationDate, details.seriesInfo, details.voiceover];

    return Padding(
      padding: EdgeInsets.only(top: AppSpacing.lg, left: inset, right: inset),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: AppSpacing.xl,
        children: [
          tvPosterAndMetadata ??
              MobileAnimePosterHeader(
                title: details.title,
                posterUri: details.posterUri,
                fallbackPosterUri: fallbackPosterUri,
                metadata: metadata,
              ),
          if (description != null && description.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: AppSpacing.lg,
              children: [
                AppSectionHeader(title: 'Сюжет', titleStyle: AppContentTypography.sectionTitleOf(context)),
                AnimeDescription(description: description),
              ],
            ),
          if (publication.any((value) => value != null && value.trim().isNotEmpty))
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: AppSpacing.sm,
              children: [
                for (final (index, field) in publication.indexed)
                  if (field case final text? when text.trim().isNotEmpty)
                    Text(
                      text,
                      style: theme.bodyLarge?.copyWith(
                        fontSize: index == 1 ? 14 : 16,
                        color: index == 1 ? AppPalette.textSecondary : null,
                      ),
                    ),
              ],
            ),
          ?watchOrder,
        ],
      ),
    );
  }

  Widget _tvPosterAndMetadata(double posterWidth, {required bool sideBySide}) => Flex(
    direction: sideBySide ? Axis.horizontal : Axis.vertical,
    crossAxisAlignment: CrossAxisAlignment.start,
    spacing: AppSpacing.xl,
    children: [
      AnimeDetailsPoster(
        title: data.details.title,
        posterUri: data.details.posterUri,
        fallbackPosterUri: fallbackPosterUri,
        maxWidth: posterWidth,
      ),
      Flexible(flex: sideBySide ? 1 : 0, child: metadata),
    ],
  );
}

/// The same transition controls measured layout, opacity, and hit testing.
class AnimeDisclosure extends StatelessWidget {
  const AnimeDisclosure({required this.progress, required this.expanded, required this.child, super.key});

  final Animation<double> progress;
  final bool expanded;
  final AnimeHero child;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: progress,
    child: child,
    builder: (context, panel) {
      if (!expanded && progress.isDismissed) return const SizedBox.shrink();

      return ExcludeFocus(
        excluding: !expanded,
        child: ExcludeSemantics(
          excluding: !expanded,
          child: IgnorePointer(
            ignoring: !expanded,
            child: SizeTransition(
              sizeFactor: progress,
              alignment: Alignment.topCenter,
              child: FadeTransition(opacity: progress, child: panel),
            ),
          ),
        ),
      );
    },
  );
}
