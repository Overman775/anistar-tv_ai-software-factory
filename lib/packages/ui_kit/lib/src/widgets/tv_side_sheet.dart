import 'package:material_ui/material_ui.dart';

import '../theme/app_palette.dart';

/// A TV action surface with a stable right edge and its own focus scope.
class TvSideSheet extends StatelessWidget {
  const TvSideSheet({required this.title, required this.child, super.key});

  final String title;
  final Widget child;

  ThemeData _theme(BuildContext context) {
    final foreground = WidgetStateColor.resolveWith(
      (states) => states.contains(WidgetState.focused) ? Colors.black : Colors.white,
    );
    final background = WidgetStateColor.resolveWith(
      (states) => states.contains(WidgetState.focused) ? Colors.white : Colors.transparent,
    );
    final style =
        TextButton.styleFrom(
          minimumSize: const Size(0, 56),
          shape: const RoundedRectangleBorder(borderRadius: AppRadii.pill),
        ).copyWith(
          foregroundColor: WidgetStateProperty.resolveWith(foreground.resolve),
          backgroundColor: WidgetStateProperty.resolveWith(background.resolve),
        );

    return Theme.of(context).copyWith(
      textButtonTheme: TextButtonThemeData(style: style),
      filledButtonTheme: FilledButtonThemeData(style: style),
      listTileTheme: ListTileThemeData(
        textColor: foreground,
        iconColor: foreground,
        selectedColor: foreground,
        selectedTileColor: Colors.white10,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.medium),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerRight,
    child: SizedBox(
      width: 440,
      height: double.infinity,
      child: Theme(
        data: _theme(context),
        child: Material(
          color: AppPalette.backgroundElevated,
          elevation: 16,
          child: SafeArea(
            minimum: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  title,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: AppSpacing.lg),
                Expanded(child: child),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

Future<T?> showTvSideSheet<T>({required BuildContext context, required WidgetBuilder builder}) =>
    Navigator.of(context, rootNavigator: true).push<T>(
      RawDialogRoute<T>(
        barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
        barrierColor: const Color(0x99000000),
        transitionDuration: AppMotion.durationOf(context, AppMotion.page),
        requestFocus: true,
        traversalEdgeBehavior: TraversalEdgeBehavior.closedLoop,
        directionalTraversalEdgeBehavior: TraversalEdgeBehavior.closedLoop,
        pageBuilder: (context, _, _) => builder(context),
        transitionBuilder: (context, animation, _, child) => SlideTransition(
          position: Tween(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).chain(CurveTween(curve: AppMotion.enterCurve)).animate(animation),
          child: child,
        ),
      ),
    );
