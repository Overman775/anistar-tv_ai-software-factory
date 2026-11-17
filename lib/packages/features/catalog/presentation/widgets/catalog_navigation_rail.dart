import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:material_ui/material_ui.dart';
import 'package:sizer/sizer.dart';
import 'package:ui_kit/ui_kit.dart';

import '../../../common/presentation/widgets/account_identity.dart';

typedef CatalogNavigationItem = ({
  Key key,
  IconData icon,
  String label,
  FocusNode focusNode,
  VoidCallback onPressed,
  bool selected,
  bool autofocus,
});

class CatalogNavigationRail extends StatelessWidget {
  const CatalogNavigationRail({
    required this.expanded,
    required this.items,
    this.accountName,
    this.accountImageUrl,
    super.key,
  });

  static double get collapsedWidth => 6.88.w.clamp(72.0, 88.0);
  static double get expandedWidth => 20.63.w.clamp(216.0, 264.0);
  static double collapsedWidthOf(BuildContext context) => AppLayoutScope.isTvOf(context) ? collapsedWidth : 88;
  static double expandedWidthOf(BuildContext context) => AppLayoutScope.isTvOf(context) ? expandedWidth : 264;

  final String? accountName;
  final String? accountImageUrl;
  final bool expanded;
  final List<CatalogNavigationItem> items;

  AppIconType _icon(CatalogNavigationItem item) => switch (item.key) {
    ValueKey(value: 'catalog-tab-true') => AppIconType.heart,
    ValueKey(value: 'catalog-account') => AppIconType.logOut,
    _ => AppIconType.fromMaterial(item.icon),
  };

  @override
  Widget build(BuildContext context) {
    final tv = AppLayoutScope.isTvOf(context);
    final collapsedSize = collapsedWidthOf(context);
    final expandedSize = expandedWidthOf(context);
    final horizontal = tv ? 1.25.w.clamp(12.0, 16.0) : AppSpacing.md;
    final iconExtent = tv ? 3.34.vmin.clamp(20.0, 24.0) : 24.0;
    final headerHeight = tv ? 12.25.h.clamp(72.0, 88.0) : 88.0;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: expanded ? 1 : 0),
      duration: AppMotion.durationOf(context, expanded ? AppMotion.panelEnter : AppMotion.panelExit),
      curve: expanded ? AppMotion.enterCurve : AppMotion.exitCurve,
      builder: (context, progress, _) => SizedBox(
        key: const ValueKey('catalog-navigation-rail'),
        width: collapsedSize + (expandedSize - collapsedSize) * progress,
        child: Material(
          color: AppPalette.backgroundElevated,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: horizontal),
            child: Column(
              children: [
                SizedBox(
                  height: math.max(headerHeight, MediaQuery.textScalerOf(context).scale(22) * 1.3 + AppSpacing.xl),
                  child: Row(
                    children: [
                      const SizedBox(width: 8),
                      const AnistarLogo(size: 40),
                      SizedBox(width: progress * AppSpacing.md),
                      Expanded(
                        child: Opacity(
                          opacity: progress,
                          child: Text(
                            'AniStar TV',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    scrollCacheExtent: const ScrollCacheExtent.pixels(600),
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                    children: [
                      for (final item in items)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: Semantics(
                            selected: item.selected,
                            label: item.label,
                            child: Tooltip(
                              message: item.label,
                              child: TextButton(
                                key: item.key,
                                focusNode: item.focusNode,
                                autofocus: item.autofocus,
                                onPressed: item.onPressed,
                                onFocusChange: (focused) {
                                  if (!focused) return;
                                  WidgetsBinding.instance.addPostFrameCallback((_) {
                                    final target = item.focusNode.context;
                                    if (target == null || !target.mounted || !item.focusNode.hasFocus) return;
                                    unawaited(
                                      Scrollable.ensureVisible(
                                        target,
                                        alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
                                      ),
                                    );
                                    unawaited(
                                      Scrollable.ensureVisible(
                                        target,
                                        alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtStart,
                                      ),
                                    );
                                  });
                                },
                                style:
                                    AppFocusStyle.button(
                                      selected: item.selected,
                                      controlExtent: tv ? AppSizes.adaptiveTvControl : AppSizes.tvControl,
                                    ).copyWith(
                                      padding: WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: horizontal)),
                                    ),
                                child: ExcludeSemantics(
                                  child: Row(
                                    children: [
                                      AppIcon(_icon(item), size: iconExtent),
                                      SizedBox(
                                        width: progress * (tv ? AppSpacing.adaptiveTvControlGap : AppSpacing.md),
                                      ),
                                      Expanded(
                                        child: Opacity(
                                          opacity: progress,
                                          child: Text(
                                            item.label,
                                            maxLines: tv || MediaQuery.textScalerOf(context).scale(16) > 16 ? 2 : 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (accountName case final name?)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md, left: AppSpacing.xs),
                    child: ClipRect(
                      child: SizedBox(
                        height: 64,
                        child: OverflowBox(
                          alignment: Alignment.centerLeft,
                          minWidth: expandedSize - AppSpacing.xl - AppSpacing.xs,
                          maxWidth: expandedSize - AppSpacing.xl - AppSpacing.xs,
                          child: AccountIdentity(name: name, imageUrl: accountImageUrl),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
