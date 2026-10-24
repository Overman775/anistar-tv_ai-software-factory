import 'package:material_ui/material_ui.dart';

import '../theme/app_content_typography.dart';
import '../theme/app_palette.dart';
import 'app_icon.dart';
import 'app_network_image.dart';
import 'media_card_bookmark.dart';
import 'media_card_caption_underlay.dart';
import 'media_card_metrics.dart';
import 'tv_focus_tile.dart';
import 'tv_poster_hero.dart';

/// A neutral media surface. Lists, status meaning and navigation belong to its caller.
class MediaCard extends StatelessWidget {
  const MediaCard({
    required this.label,
    required this.onPressed,
    this.imageUrl,
    this.caption,
    this.showCaption = true,
    this.showBookmark = false,
    this.showEpisodeTrailing = false,
    this.episodeHeight,
    this.semanticLabel,
    this.variant = MediaCardVariant.poster,
    this.fit,
    this.heroTag,
    this.fallbackImageUrl,
    this.badges = const [],
    this.leading,
    this.trailing,
    this.focusNode,
    this.autofocus = false,
    this.enabled = true,
    this.busy = false,
    this.selected = false,
    this.onLongPressed,
    this.onFocusChanged,
    super.key,
  });

  final String label;
  final String? imageUrl;
  final String? caption;
  final bool showCaption;
  final bool showBookmark;
  final bool showEpisodeTrailing;
  final double? episodeHeight;
  final String? semanticLabel;
  final MediaCardVariant variant;
  final BoxFit? fit;
  final Object? heroTag;
  final String? fallbackImageUrl;
  final List<Widget> badges;
  final Widget? leading;
  final Widget? trailing;
  final FocusNode? focusNode;
  final bool autofocus;
  final bool enabled;
  final bool busy;
  final bool selected;
  final VoidCallback onPressed;
  final VoidCallback? onLongPressed;
  final ValueChanged<bool>? onFocusChanged;

  Widget _image() {
    final tag = heroTag;
    final resolvedFit = fit ?? (variant == MediaCardVariant.landscape ? BoxFit.contain : BoxFit.cover);
    if (variant == MediaCardVariant.poster && tag != null) {
      return TvPosterHero(
        tag: tag,
        imageUrl: imageUrl,
        semanticLabel: label,
        fallbackImageUrl: fallbackImageUrl,
        fit: resolvedFit,
      );
    }

    return AppNetworkImage(
      imageUrl: imageUrl,
      fallbackImageUrl: fallbackImageUrl,
      fit: resolvedFit,
      borderRadius: AppRadii.large,
    );
  }

  Widget _copy(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      ExcludeSemantics(
        child: Text(
          label,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style:
              (variant == MediaCardVariant.episode
                      ? AppContentTypography.episodeTitleOf(context)
                      : AppContentTypography.cardTitleOf(context))
                  ?.copyWith(color: AppPalette.textPrimary, fontWeight: FontWeight.w600),
        ),
      ),
      if (showCaption)
        if (caption case final String caption) ...[
          const SizedBox(height: AppSpacing.xs),
          ExcludeSemantics(
            child: Text(
              caption,
              maxLines: variant == MediaCardVariant.episode ? 2 : null,
              overflow: variant == MediaCardVariant.episode ? TextOverflow.ellipsis : TextOverflow.clip,
              style:
                  (variant == MediaCardVariant.episode
                          ? AppContentTypography.episodeCaptionOf(context)
                          : AppContentTypography.cardCaptionOf(context))
                      ?.copyWith(color: AppPalette.textSecondary),
            ),
          ),
        ],
    ],
  );

  Widget _episode() => LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.hasBoundedWidth ? constraints.maxWidth : AppSizes.sideSheet;
      final metrics = MediaCardMetrics(
        width: width,
        label: label,
        caption: caption,
        showCaption: showCaption,
        minimumHeight: episodeHeight,
        titleStyle: AppContentTypography.episodeTitleOf(context)
            ?.copyWith(color: AppPalette.textPrimary, fontWeight: FontWeight.w600),
        captionStyle: AppContentTypography.episodeCaptionOf(context)?.copyWith(color: AppPalette.textSecondary),
        textScaler: MediaQuery.textScalerOf(context),
        direction: Directionality.of(context),
      );
      final surface = Stack(
        fit: StackFit.expand,
        children: [
          ExcludeSemantics(child: _image()),
          MediaCardCaptionUnderlay(child: _copy(context)),
          if (leading case final leading?)
            Positioned(
              top: AppSpacing.sm,
              left: AppSpacing.sm,
              child: ExcludeSemantics(child: leading),
            ),
          if (busy)
            const Positioned(
              top: AppSpacing.sm,
              left: AppSpacing.sm,
              child: SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            ),
          if (badges.isNotEmpty)
            Positioned(
              top: AppSpacing.sm,
              right: AppSpacing.sm,
              child: Row(mainAxisSize: MainAxisSize.min, spacing: AppSpacing.xs, children: badges),
            ),
          if (showEpisodeTrailing)
            Positioned(
              right: AppSpacing.sm,
              bottom: AppSpacing.sm,
              child: ExcludeSemantics(child: trailing ?? const AppIcon(AppIconType.play, size: 24)),
            ),
        ],
      );

      return SizedBox(height: metrics.episodeHeight, child: surface);
    },
  );

  @override
  Widget build(BuildContext context) => TvFocusTile(
    focusNode: focusNode,
    autofocus: autofocus,
    enabled: enabled,
    busy: busy,
    selected: selected,
    onPressed: onPressed,
    onLongPressed: onLongPressed,
    onFocusChanged: onFocusChanged,
    semanticLabel: semanticLabel ?? [label, if (showCaption && caption != null) caption].join(', '),
    builder: (context, focused) {
      if (variant == MediaCardVariant.episode) {
        return _episode();
      }

      return AspectRatio(
        aspectRatio: variant == MediaCardVariant.poster ? AppSizes.posterRatio : AppSizes.landscapeRatio,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ExcludeSemantics(child: _image()),
            MediaCardCaptionUnderlay(child: _copy(context)),
            if (busy)
              const Positioned(
                top: AppSpacing.sm,
                left: AppSpacing.sm,
                child: SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2)),
              ),
            if (badges.isNotEmpty)
              Positioned(
                top: AppSpacing.sm,
                left: AppSpacing.sm,
                child: Row(mainAxisSize: MainAxisSize.min, spacing: AppSpacing.xs, children: badges),
              ),
            if (showBookmark) const Positioned(top: 0, right: AppSpacing.md, child: MediaCardBookmark()),
          ],
        ),
      );
    },
  );
}

/// Visual variants share activation, focus, clipping and image fallbacks.
enum MediaCardVariant { poster, landscape, episode }
