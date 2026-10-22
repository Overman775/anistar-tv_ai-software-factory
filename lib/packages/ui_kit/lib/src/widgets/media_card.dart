import 'package:material_ui/material_ui.dart';

import '../theme/app_content_typography.dart';
import '../theme/app_palette.dart';
import 'app_icon.dart';
import 'app_network_image.dart';
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
      if (caption case final caption?) ...[
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
      final copy = Row(
        children: [
          if (leading case final leading?) ...[leading, const SizedBox(width: AppSpacing.md)],
          Expanded(child: _copy(context)),
          const SizedBox(width: AppSpacing.sm),
          if (busy) ...[
            const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            const SizedBox(width: AppSpacing.sm),
          ],
          if (badges.isNotEmpty) ...[...badges, const SizedBox(width: AppSpacing.sm)],
          trailing ?? const AppIcon(AppIconType.play, size: 24),
        ],
      );

      if (constraints.maxWidth < 320) {
        final preview = AspectRatio(
          aspectRatio: AppSizes.episodeRatio,
          child: ExcludeSemantics(child: _image()),
        );

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (constraints.hasBoundedHeight)
              Flexible(
                child: Align(alignment: Alignment.topCenter, heightFactor: 1, child: preview),
              )
            else
              preview,
            Padding(padding: const EdgeInsets.all(AppSpacing.md), child: copy),
          ],
        );
      }

      return Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            SizedBox(
              width: 96,
              child: AspectRatio(
                aspectRatio: AppSizes.episodeRatio,
                child: ExcludeSemantics(child: _image()),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: copy),
          ],
        ),
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
    onPressed: onPressed,
    onLongPressed: onLongPressed,
    onFocusChanged: onFocusChanged,
    semanticLabel: semanticLabel ?? [label, if (caption != null) caption].join(', '),
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
            if (showCaption)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, AppPalette.mediaCaptionShade, AppPalette.media],
                      stops: [0, 0.48, 1],
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.xxl, AppSpacing.md, AppSpacing.md),
                    child: _copy(context),
                  ),
                ),
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
          ],
        ),
      );
    },
  );
}

/// Visual variants share activation, focus, clipping and image fallbacks.
enum MediaCardVariant { poster, landscape, episode }
