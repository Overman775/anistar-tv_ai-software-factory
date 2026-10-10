import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../theme/app_focus_style.dart';
import '../theme/app_palette.dart';

/// A TV action surface with a stable right edge and its own focus scope.
class TvSideSheet extends StatelessWidget {
  const TvSideSheet({required this.title, required this.child, super.key});

  final String title;
  final Widget child;

  ThemeData _theme(BuildContext context) {
    final style = AppFocusStyle.button();

    return Theme.of(context).copyWith(
      focusColor: AppPalette.focusSurface,
      hoverColor: AppPalette.focusSurface,
      textButtonTheme: TextButtonThemeData(style: style),
      filledButtonTheme: FilledButtonThemeData(style: style),
      listTileTheme: const ListTileThemeData(
        textColor: AppPalette.textPrimary,
        iconColor: AppPalette.textPrimary,
        selectedColor: AppPalette.textPrimary,
        selectedTileColor: AppPalette.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: AppRadii.medium),
      ),
    );
  }

  KeyEventResult _handleKey(BuildContext context, KeyEvent event) {
    if (event.logicalKey != LogicalKeyboardKey.arrowLeft) {
      return KeyEventResult.ignored;
    }
    if (event is KeyDownEvent) {
      Navigator.of(context).pop();
    }

    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerRight,
    child: SizedBox(
      width: 440,
      height: double.infinity,
      child: Theme(
        data: _theme(context),
        child: Focus(
          canRequestFocus: false,
          onKeyEvent: (_, event) => _handleKey(context, event),
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
