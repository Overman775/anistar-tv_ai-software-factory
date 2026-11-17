import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:sizer/sizer.dart';

import '../theme/app_content_typography.dart';
import '../theme/app_palette.dart';
import '../theme/app_typography.dart';
import 'app_icon.dart';
import 'app_layout_scope.dart';
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
    this.titleStyle,
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

  /// Overrides the visual title/caption role without changing the accessible label.
  final TextStyle? titleStyle;

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
      (titleStyle ??
              (variant == MediaCardVariant.episode
                  ? AppContentTypography.episodeTitleOf(context)
                  : AppContentTypography.cardTitleOf(context)))
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
      final tv = AppLayoutScope.isTvOf(context);
      final inset = tv ? 1.12.h.clamp(6.0, 8.0) : AppSpacing.sm;
      final markPadding = tv ? 0.56.h.clamp(3.0, 4.0) : AppSpacing.xs;
      final markGlyph = tv ? 2.78.vmin.clamp(16.0, 20.0) : 20.0;
      final trailingGlyph = tv ? 3.34.vmin.clamp(20.0, 24.0) : 24.0;
      final metrics = MediaCardMetrics(
        width: width,
        label: label,
        caption: caption,
        showCaption: showCaption,
        minimumHeight: episodeHeight,
        titleStyle: _titleStyle(context),
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
              top: inset,
              left: inset,
              child: ExcludeSemantics(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: markPadding,
                  children: [
                    if (selected) _EpisodeMark(color: AppPalette.primary, padding: markPadding, glyph: markGlyph),
                    ?leading,
                    if (busy) const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                  ],
                ),
              ),
            ),
          if (isWatched || badges.isNotEmpty)
            Positioned(
              top: inset,
              right: inset,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                spacing: markPadding,
                children: [
                  if (isWatched) _EpisodeMark(color: AppPalette.success, padding: markPadding, glyph: markGlyph),
                  ...badges,
                ],
              ),
            ),
          if (showEpisodeTrailing)
            Positioned(
              right: inset,
              bottom: inset,
              child: ExcludeSemantics(child: trailing ?? AppIcon(AppIconType.play, size: trailingGlyph)),
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

      final tv = AppLayoutScope.isTvOf(context);
      final badgeInset = tv ? 0.63.w.clamp(6.0, 8.0) : AppSpacing.sm;
      final bookmarkInset = tv ? 1.25.w.clamp(12.0, 16.0) : AppSpacing.md;
      final ratingIcon = tv ? 2.23.vmin.clamp(14.0, 16.0) : 16.0;
      final ratingText = tv
          ? AppTypography.metadataControlTextOf(context)
                ?.copyWith(color: AppPalette.textPrimary, fontWeight: FontWeight.w700)
          : null;
      final bookmarkWidth = tv ? 2.82.w.clamp(30.0, 36.0) : 36.0;
      final bookmarkHeight = tv ? 6.67.h.clamp(40.0, 48.0) : 48.0;
      final bookmarkGlyph = tv ? 3.89.vmin.clamp(22.0, 28.0) : 28.0;

      return AspectRatio(
        aspectRatio: variant == MediaCardVariant.poster ? AppSizes.posterRatio : AppSizes.landscapeRatio,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ExcludeSemantics(child: _image()),
            CustomMultiChildLayout(
              delegate: _PosterOverlayLayout(badgeInset: badgeInset, bookmarkInset: bookmarkInset),
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
                            child: AppMetadataBadge(
                              icon: Icons.grade_rounded,
                              label: rating,
                              iconSize: ratingIcon,
                              textStyle: ratingText,
                            ),
                          ),
                        for (final badge in badges) Flexible(child: badge),
                        if (busy)
                          const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                      ],
                    ),
                  ),
                if (showBookmark)
                  LayoutId(
                    id: _PosterOverlay.bookmark,
                    child: MediaCardBookmark(
                      width: bookmarkWidth,
                      height: bookmarkHeight,
                      iconSize: bookmarkGlyph,
                      inset: tv ? bookmarkWidth * 0.11 : 4,
                      notch: bookmarkHeight * 0.125,
                      padding: tv
                          ? EdgeInsets.fromLTRB(
                              bookmarkWidth * 0.11,
                              bookmarkHeight * 0.17,
                              bookmarkWidth * 0.11,
                              bookmarkHeight * 0.25,
                            )
                          : const EdgeInsets.fromLTRB(4, 8, 4, 12),
                    ),
                  ),
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
  _PosterOverlayLayout({required this.badgeInset, required this.bookmarkInset});

  final double badgeInset;
  final double bookmarkInset;

  @override
  void performLayout(Size size) {
    final badgeOffset = Offset(badgeInset, badgeInset);
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
      final left = size.width - bookmarkInset - bookmark.width;
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
  bool shouldRelayout(covariant _PosterOverlayLayout oldDelegate) =>
      oldDelegate.badgeInset != badgeInset || oldDelegate.bookmarkInset != bookmarkInset;
}

class _EpisodeMark extends StatelessWidget {
  const _EpisodeMark({required this.color, required this.padding, required this.glyph});

  final Color color;
  final double padding;
  final double glyph;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(color: AppPalette.badge, borderRadius: AppRadii.small),
    child: Padding(
      padding: EdgeInsets.all(padding),
      child: AppIcon(AppIconType.check, color: color, size: glyph),
    ),
  );
}
