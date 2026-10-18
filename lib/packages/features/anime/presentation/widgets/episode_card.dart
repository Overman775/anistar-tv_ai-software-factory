import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';

import '../../domain/models/anime_episode.dart';
import 'episode_caption.dart';

class EpisodeCard extends StatelessWidget {
  const EpisodeCard({
    required this.episode,
    required this.onTap,
    super.key,
    this.autofocus = false,
    this.focusNode,
    this.isWatched = false,
    this.onFocusChanged,
  });

  final bool autofocus;
  final FocusNode? focusNode;
  final bool isWatched;
  final AnimeEpisode episode;
  final ValueChanged<bool>? onFocusChanged;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final preview = episode.previewUri;
    final watched = isWatched || episode.isWatched;
    final caption = EpisodeCaption(number: episode.number, title: episode.title);
    final description = caption.descriptiveTitle;

    return TvFocusTile(
      autofocus: autofocus,
      focusNode: focusNode,
      onFocusChanged: onFocusChanged,
      onPressed: onTap,
      semanticLabel: caption.semanticLabel(isWatched: watched),
      builder: (context, focused) {
        final theme = Theme.of(context);
        final primary = theme.colorScheme.primary;
        final textTheme = theme.textTheme;

        return ExcludeSemantics(
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (preview != null)
                AppNetworkImage(imageUrl: preview.toString(), semanticLabel: episode.title)
              else
                const ColoredBox(
                  color: AppPalette.surfaceElevated,
                  child: Center(child: Icon(Icons.movie_outlined, size: 44, color: AppPalette.textSecondary)),
                ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x22000000), Color(0xEE080B14)],
                  ),
                ),
              ),
              Positioned(
                top: AppSpacing.sm,
                left: AppSpacing.sm,
                right: AppSpacing.sm,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Flexible(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: const Color(0xD9080B14),
                          borderRadius: AppRadii.pill,
                          border: Border.fromBorderSide(
                            BorderSide(color: focused ? primary : AppPalette.outline, width: focused ? 2 : 1),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                          child: Text(
                            caption.numberLabel.toUpperCase(),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.labelMedium?.copyWith(
                              color: focused ? Colors.white : AppPalette.textSecondary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (watched) ...[
                      const SizedBox(width: AppSpacing.xs),
                      const DecoratedBox(
                        decoration: BoxDecoration(color: Color(0xD9080B14), shape: BoxShape.circle),
                        child: Padding(
                          padding: EdgeInsets.all(AppSpacing.xs),
                          child: Icon(
                            Icons.check_circle_rounded,
                            color: AppPalette.textPrimary,
                            semanticLabel: 'Просмотрена',
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Positioned(
                left: AppSpacing.md,
                right: AppSpacing.md,
                bottom: AppSpacing.md,
                child: Row(
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: focused ? primary : AppPalette.surfaceElevated.withValues(alpha: 0.88),
                        shape: BoxShape.circle,
                      ),
                      child: const Padding(
                        padding: EdgeInsets.all(AppSpacing.xs),
                        child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: 26),
                      ),
                    ),
                    if (description != null) ...[
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.titleMedium?.copyWith(
                            color: AppPalette.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
