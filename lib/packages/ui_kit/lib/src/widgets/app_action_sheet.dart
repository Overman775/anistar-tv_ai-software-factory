import 'package:material_ui/material_ui.dart';

import '../theme/app_palette.dart';
import 'app_icon.dart';
import 'app_responsive_root.dart';
import 'tv_side_sheet.dart';

/// Shared action content, presented according to the active interaction profile.
class AppActionSheet extends StatelessWidget {
  const AppActionSheet({
    required this.title,
    required this.child,
    this.mobileHeightFactor = 0.75,
    this.closeOnLeft = true,
    this.expandChild = false,
    super.key,
  });

  final String title;
  final Widget child;
  final double mobileHeightFactor;
  final bool closeOnLeft;
  final bool expandChild;

  @override
  Widget build(BuildContext context) {
    if (AppLayoutScope.isTvOf(context)) {
      return TvSideSheet(title: title, closeOnLeft: closeOnLeft, expandChild: expandChild, child: child);
    }
    final media = MediaQuery.of(context);
    final availableHeight = (media.size.height - media.padding.top - media.viewInsets.bottom).clamp(
      0.0,
      double.infinity,
    );
    final height = availableHeight * mobileHeightFactor.clamp(0.35, 0.9);

    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: height,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              AppLayoutScope.horizontalPaddingOf(context),
              8,
              AppLayoutScope.horizontalPaddingOf(context),
              16,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 32,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: const BoxDecoration(color: AppPalette.textSecondary, borderRadius: AppRadii.pill),
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Закрыть',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const AppIcon(AppIconType.x),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (expandChild) Expanded(child: child) else child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<T?> showAppActionSheet<T>({required BuildContext context, required WidgetBuilder builder}) {
  if (AppLayoutScope.isTvOf(context)) {
    return showTvSideSheet<T>(context: context, builder: builder);
  }

  return showModalBottomSheet<T>(
    context: context,
    useRootNavigator: true,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: AppPalette.backgroundElevated,
    constraints: const BoxConstraints(maxWidth: AppSizes.bottomSheetMaxWidth),
    sheetAnimationStyle: AnimationStyle(
      duration: AppMotion.durationOf(context, AppMotion.panelEnter),
      reverseDuration: AppMotion.durationOf(context, AppMotion.panelExit),
    ),
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
    builder: builder,
  );
}
