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
                height: 88,
                child: Row(
                  children: [
                    const SizedBox(width: 16),
                    const Icon(Icons.live_tv_rounded, color: AppPalette.primary),
                    SizedBox(width: progress * 16),
                    Expanded(
                      child: Opacity(
                        opacity: progress,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'AniStar TV',
                              maxLines: 1,
                              overflow: TextOverflow.clip,
                              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                            ),
                            if (accountName case final name?)
                              Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 13, color: AppPalette.textSecondary),
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
                              style:
                                  TextButton.styleFrom(
                                    minimumSize: const Size(56, 56),
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                    shape: const RoundedRectangleBorder(borderRadius: AppRadii.pill),
                                  ).copyWith(
                                    foregroundColor: WidgetStateProperty.resolveWith(
                                      (states) => states.contains(WidgetState.focused) ? Colors.black : Colors.white,
                                    ),
                                    backgroundColor: WidgetStateProperty.resolveWith((states) {
                                      if (states.contains(WidgetState.focused)) {
                                        return Colors.white;
                                      }

                                      return item.selected ? AppPalette.surfaceElevated : Colors.transparent;
                                    }),
                                  ),
                              child: ExcludeSemantics(
                                child: Row(
                                  children: [
                                    Icon(item.icon, size: 24),
                                    SizedBox(width: progress * 16),
                                    Expanded(
                                      child: Opacity(
                                        opacity: progress,
                                        child: Text(item.label, maxLines: 1, overflow: TextOverflow.clip),
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
