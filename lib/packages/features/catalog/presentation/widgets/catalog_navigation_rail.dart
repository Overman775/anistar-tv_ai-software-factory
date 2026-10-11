import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';

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

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: expanded ? 1 : 0),
    duration: AppMotion.durationOf(context, AppMotion.standard),
    curve: AppMotion.enterCurve,
    builder: (context, progress, _) => SizedBox(
      key: const ValueKey('catalog-navigation-rail'),
      width: collapsedWidth + (expandedWidth - collapsedWidth) * progress,
      child: Material(
        color: Color.lerp(Colors.transparent, AppPalette.backgroundElevated, progress),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              SizedBox(
                height: math.max(
                  88,
                  MediaQuery.textScalerOf(context).scale(22) * 1.2 +
                      (accountName == null ? 0 : MediaQuery.textScalerOf(context).scale(14) * 1.4) +
                      24,
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 16),
                    const AnistarLogo(),
                    SizedBox(width: progress * 16),
                    Expanded(
                      child: Opacity(
                        opacity: progress,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'AniStar TV',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 22, height: 1.2),
                            ),
                            if (accountName case final name?)
                              Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppPalette.textSecondary),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  children: [
                    for (final item in items)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
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
                              style: AppFocusStyle.button(
                                selected: item.selected,
                              ).copyWith(padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 16))),
                              child: ExcludeSemantics(
                                child: Row(
                                  children: [
                                    Icon(item.icon, size: 24),
                                    SizedBox(width: progress * 16),
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
            ],
          ),
        ),
      ),
    ),
  );
}
