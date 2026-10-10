import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';

/// Quiet page motion; the video surface only fades and never scales.
class AppNavigationPage extends CustomTransitionPage<void> {
  AppNavigationPage({required BuildContext context, required LocalKey key, required super.child, bool player = false})
    : super(
        key: key,
        transitionDuration: AppMotion.durationOf(context, player ? AppMotion.fast : AppMotion.page),
        reverseTransitionDuration: AppMotion.durationOf(context, player ? AppMotion.fast : AppMotion.pageReverse),
        transitionsBuilder: player ? _fade : _detail,
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

  static Widget _detail(BuildContext context, Animation<double> animation, Animation<double> secondary, Widget child) {
    if (AppMotion.reducedOf(context)) {
      return child;
    }
    final curved = animation.drive(CurveTween(curve: AppMotion.enterCurve));

    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.02), end: Offset.zero).animate(curved),
        child: child,
      ),
    );
  }
}
