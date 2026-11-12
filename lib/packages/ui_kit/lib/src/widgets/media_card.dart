import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../theme/app_content_typography.dart';
import '../theme/app_palette.dart';
import 'app_icon.dart';
import 'app_metadata_badge.dart';
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
    this.ratingLabel,
    this.isWatched = false,
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
    this.scaleOnFocus = true,
    this.onLongPressed,
    this.onFocusChanged,
    super.key,
  });

  final String label;
  final String? imageUrl;
  final String? caption;
  final bool showCaption;
  final bool showBookmark;

  /// A localized score, without its scale. The caller decides where it is shown.
  final String? ratingLabel;
  final bool isWatched;
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
  final bool scaleOnFocus;
  final VoidCallback onPressed;
  final VoidCallback? onLongPressed;
  final ValueChanged<bool>? onFocusChanged;

  String get _accessibleLabel {
    final score = ratingLabel;
    final description = semanticLabel ?? [label, if (showCaption) ?caption].join(', ');
    final episode = variant == MediaCardVariant.episode;

    return [
      description,
      if (!episode && score != null) 'Рейтинг $score из 10',
      if (!episode && showBookmark) 'В избранном',
      if (episode && semanticLabel == null && selected) 'текущая',
      if (episode && semanticLabel == null && isWatched) 'просмотрена',
    ].join(', ');
  }

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

  TextStyle? _titleStyle(BuildContext context) =>
      (variant == MediaCardVariant.episode
              ? AppContentTypography.episodeTitleOf(context)
              : AppContentTypography.cardTitleOf(context))
          ?.copyWith(color: AppPalette.textPrimary, fontWeight: FontWeight.w600);

  Widget _copy(BuildContext context, {int titleLines = 2, bool compact = false}) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      ExcludeSemantics(
        child: Text(label, maxLines: titleLines, overflow: TextOverflow.ellipsis, style: _titleStyle(context)),
      ),
      if (showCaption && !compact)
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
          Positioned(left: 0, right: 0, bottom: 0, child: MediaCardCaptionUnderlay(child: _copy(context))),
          if (selected || busy || leading != null)
            Positioned(
              top: AppSpacing.sm,
              left: AppSpacing.sm,
              child: ExcludeSemantics(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: AppSpacing.xs,
                  children: [
                    if (selected) const _EpisodeMark(color: AppPalette.primary),
                    ?leading,
                    if (busy) const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                  ],
                ),
              ),
            ),
          if (isWatched || badges.isNotEmpty)
            Positioned(
              top: AppSpacing.sm,
              right: AppSpacing.sm,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                spacing: AppSpacing.xs,
                children: [
                  if (isWatched) const _EpisodeMark(color: AppPalette.success),
                  ...badges,
                ],
              ),
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

  Widget _posterCaption() => LayoutBuilder(
    builder: (context, constraints) {
      if (!constraints.hasBoundedHeight) return MediaCardCaptionUnderlay(child: _copy(context));

      final painter = TextPainter(
        text: TextSpan(text: label, style: _titleStyle(context)),
        textScaler: MediaQuery.textScalerOf(context),
        textDirection: Directionality.of(context),
        maxLines: 2,
      )..layout(maxWidth: math.max(0, constraints.maxWidth - AppSpacing.md * 2));
      final copyHeight = painter.height;
      painter.dispose();
      final compact = constraints.maxHeight < copyHeight + AppSpacing.xxl + AppSpacing.md;
      final lines = compact && constraints.maxHeight < copyHeight ? 1 : 2;

      return MediaCardCaptionUnderlay(
        compact: compact,
        child: _copy(context, titleLines: lines, compact: compact),
      );
    },
  );

  @override
  Widget build(BuildContext context) => TvFocusTile(
    focusNode: focusNode,
    autofocus: autofocus,
    enabled: enabled,
    busy: busy,
    selected: selected,
    scaleOnFocus: scaleOnFocus,
    onPressed: onPressed,
    onLongPressed: onLongPressed,
    onFocusChanged: onFocusChanged,
    semanticLabel: _accessibleLabel,
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
            CustomMultiChildLayout(
              delegate: _PosterOverlayLayout(),
              children: [
                LayoutId(id: _PosterOverlay.caption, child: _posterCaption()),
                if (busy || ratingLabel != null || badges.isNotEmpty)
                  LayoutId(
                    id: _PosterOverlay.badges,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      spacing: AppSpacing.xs,
                      children: [
                        if (ratingLabel case final rating?)
                          Flexible(
                            child: AppMetadataBadge(icon: Icons.grade_rounded, label: rating),
                          ),
                        for (final badge in badges) Flexible(child: badge),
                        if (busy)
                          const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                      ],
                    ),
                  ),
                if (showBookmark) LayoutId(id: _PosterOverlay.bookmark, child: const MediaCardBookmark()),
              ],
            ),
          ],
        ),
      );
    },
  );
}

/// Visual variants share activation, focus, clipping and image fallbacks.
enum MediaCardVariant { poster, landscape, episode }

enum _PosterOverlay { caption, badges, bookmark }

class _PosterOverlayLayout extends MultiChildLayoutDelegate {
  @override
  void performLayout(Size size) {
    const badgeOffset = Offset(AppSpacing.sm, AppSpacing.sm);
    final loose = BoxConstraints.loose(size);
    var badgeSize = Size.zero;
    if (hasChild(_PosterOverlay.badges)) {
      badgeSize = layoutChild(
        _PosterOverlay.badges,
        BoxConstraints(maxWidth: math.max(0, size.width - badgeOffset.dx - AppSizes.focusStroke)),
      );
      positionChild(_PosterOverlay.badges, badgeOffset);
    }

    var captionTop = 0.0;
    if (hasChild(_PosterOverlay.bookmark)) {
      final bookmark = layoutChild(_PosterOverlay.bookmark, loose);
      final left = size.width - AppSpacing.md - bookmark.width;
      final overlaps = badgeSize.width > 0 && badgeOffset.dx + badgeSize.width > left;
      final top = overlaps ? badgeOffset.dy + badgeSize.height + AppSpacing.xs : 0.0;
      positionChild(_PosterOverlay.bookmark, Offset(left, top));
      if (overlaps) captionTop = top + bookmark.height;
    }

    final caption = layoutChild(
      _PosterOverlay.caption,
      BoxConstraints(
        minWidth: size.width,
        maxWidth: size.width,
        maxHeight: captionTop > 0 ? math.max(0, size.height - captionTop) : double.infinity,
      ),
    );
    positionChild(_PosterOverlay.caption, Offset(0, size.height - caption.height));
  }

  @override
  bool shouldRelayout(covariant _PosterOverlayLayout oldDelegate) => false;
}

class _EpisodeMark extends StatelessWidget {
  const _EpisodeMark({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(color: AppPalette.badge, borderRadius: AppRadii.small),
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.xs),
      child: AppIcon(AppIconType.check, color: color, size: 20),
    ),
  );
}
