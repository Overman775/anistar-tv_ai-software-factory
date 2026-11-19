import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';

/// Fades the player route without transforming its video surface.
class AppNavigationPage extends CustomTransitionPage<void> {
  AppNavigationPage({required BuildContext context, required LocalKey key, required super.child})
    : super(
        key: key,
        transitionDuration: AppMotion.durationOf(context, AppMotion.fast),
        reverseTransitionDuration: AppMotion.durationOf(context, AppMotion.fast),
        transitionsBuilder: _fade,
      );

  static Widget _fade(BuildContext context, Animation<double> animation, Animation<double> secondary, Widget child) {
    if (AppMotion.reducedOf(context)) {
      return child;
    }

    return FadeTransition(
      opacity: animation.drive(CurveTween(curve: AppMotion.enterCurve)),
      child: child,
    );
  }
}
