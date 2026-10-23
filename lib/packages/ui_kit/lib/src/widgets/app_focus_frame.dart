import 'package:material_ui/material_ui.dart';

import '../theme/app_palette.dart';

class AppFocusFrame extends StatelessWidget {
  const AppFocusFrame({
    required this.active,
    required this.color,
    required this.restingColor,
    required this.radius,
    required this.width,
    required this.child,
    super.key,
  });

  final Color color;
  final Color restingColor;
  final BorderRadius radius;
  final double width;
  final Widget child;
  final bool active;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<Color?>(
    tween: ColorTween(begin: restingColor, end: active ? color : restingColor),
    duration: AppMotion.durationOf(context, active ? AppMotion.focusBorderEnter : AppMotion.focusBorderExit),
    curve: active ? AppMotion.enterCurve : AppMotion.exitCurve,
    builder: (context, value, child) => DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(color: value ?? restingColor, width: width),
      ),
      child: child,
    ),
    child: child,
  );
}
