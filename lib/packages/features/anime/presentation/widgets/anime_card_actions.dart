import 'package:material_ui/material_ui.dart';
import 'package:sizer/sizer.dart';
import 'package:ui_kit/ui_kit.dart';

const _detailsLabel = 'Подробнее';

/// Keeps the action row's layout stable between loading and confirmed data.
class AnimeCardActions extends StatelessWidget {
  const AnimeCardActions({
    required this.showFavorite,
    this.onToggleDetails,
    this.expanded = false,
    this.detailsFocus,
    this.favoriteAction,
    super.key,
  });

  final bool showFavorite;
  final VoidCallback? onToggleDetails;
  final bool expanded;
  final FocusNode? detailsFocus;
  final Widget? favoriteAction;

  @override
  Widget build(BuildContext context) {
    final tv = AppLayoutScope.isTvOf(context);
    final loading = onToggleDetails == null;
    final details = Semantics(
      expanded: expanded,
      child: AppButton(
        label: _detailsLabel,
        variant: AppButtonVariant.neutral,
        focusNode: detailsFocus,
        adaptiveTv: tv,
        enabled: !loading,
        icon: RotatedBox(
          quarterTurns: expanded ? 3 : 1,
          child: AppIcon(AppIconType.chevronRight, size: tv ? 2.78.vmin.clamp(18.0, 20.0) : 20),
        ),
        onPressed: () => onToggleDetails?.call(),
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) => Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: [
          if (loading)
            Stack(
              key: const ValueKey('anime-details-loading'),
              children: [
                // Keep the ready button's size at the current text scale.
                ExcludeSemantics(
                  child: ExcludeFocus(
                    child: IgnorePointer(child: Opacity(opacity: 0, child: details)),
                  ),
                ),
                const Positioned.fill(child: TvSkeletonBox()),
              ],
            )
          else
            details,
          if (showFavorite)
            ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: tv ? constraints.maxWidth : _mobileFavoriteWidth(context, constraints.maxWidth),
              ),
              child: Stack(
                children: [
                  // Reserve space for the longest label, including its wrapped lines.
                  const Opacity(
                    opacity: 0,
                    child: ExcludeSemantics(
                      child: ExcludeFocus(child: IgnorePointer(child: _FavoriteActionSize())),
                    ),
                  ),
                  Positioned.fill(
                    child: favoriteAction == null
                        ? const TvSkeletonBox(key: ValueKey('anime-favorite-loading'))
                        : Align(alignment: Alignment.topLeft, child: favoriteAction),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  double _mobileFavoriteWidth(BuildContext context, double available) {
    final afterDetails = available - _mobileButtonWidth(context, _detailsLabel) - AppSpacing.sm;
    // Keep confirmed actions alongside Details whenever they fit. The longer
    // status-check label may wrap inside its slot in the same row.
    return afterDetails >= _mobileButtonWidth(context, 'В избранное') &&
            afterDetails >= _mobileButtonWidth(context, 'В избранном')
        ? afterDetails
        : available;
  }

  double _mobileButtonWidth(BuildContext context, String label) {
    final painter = TextPainter(
      text: TextSpan(
        text: label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(fontSize: 16, fontWeight: FontWeight.w600),
      ),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final width = painter.width.ceilToDouble() + 2 * AppSpacing.md + AppSpacing.sm + 20;
    painter.dispose();

    return width;
  }
}

class _FavoriteActionSize extends StatelessWidget {
  const _FavoriteActionSize();

  @override
  Widget build(BuildContext context) => AppButton(
    label: 'Проверить избранное',
    variant: AppButtonVariant.neutral,
    adaptiveTv: AppLayoutScope.isTvOf(context),
    enabled: false,
    icon: const AppIcon(AppIconType.heartPlus),
    onPressed: () => throw StateError('The favorite sizing control cannot be activated.'),
  );
}
