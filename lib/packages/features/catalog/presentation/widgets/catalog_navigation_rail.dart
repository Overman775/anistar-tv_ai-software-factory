import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
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
  const CatalogNavigationRail({required this.expanded, required this.items, this.accountName, super.key});

  static const collapsedWidth = 88.0;
  static const expandedWidth = 264.0;

  final String? accountName;
  final bool expanded;
  final List<CatalogNavigationItem> items;

  AppIconType _icon(CatalogNavigationItem item) => switch (item.key) {
    ValueKey(value: 'catalog-tab-true') => AppIconType.heart,
    ValueKey(value: 'catalog-account') => AppIconType.logOut,
    _ => AppIconType.fromMaterial(item.icon),
  };

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: expanded ? 1 : 0),
    duration: AppMotion.durationOf(context, expanded ? AppMotion.panelEnter : AppMotion.panelExit),
    curve: expanded ? AppMotion.enterCurve : AppMotion.exitCurve,
    builder: (context, progress, _) => SizedBox(
      key: const ValueKey('catalog-navigation-rail'),
      width: collapsedWidth + (expandedWidth - collapsedWidth) * progress,
      child: Material(
        color: AppPalette.backgroundElevated,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Column(
            children: [
              SizedBox(
                height: math.max(88, MediaQuery.textScalerOf(context).scale(22) * 1.3 + AppSpacing.xl),
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
                              style: AppFocusStyle.button(selected: item.selected).copyWith(
                                padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: AppSpacing.md)),
                              ),
                              child: ExcludeSemantics(
                                child: Row(
                                  children: [
                                    AppIcon(_icon(item), size: 24),
                                    SizedBox(width: progress * AppSpacing.md),
                                    Expanded(
                                      child: Opacity(
                                        opacity: progress,
                                        child: Text(
                                          item.label,
                                          maxLines: MediaQuery.textScalerOf(context).scale(16) > 16 ? 2 : 1,
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
                        minWidth: expandedWidth - AppSpacing.xl - AppSpacing.xs,
                        maxWidth: expandedWidth - AppSpacing.xl - AppSpacing.xs,
                        child: AccountIdentity(name: name),
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
