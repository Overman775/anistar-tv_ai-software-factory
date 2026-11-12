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
  Widget build(BuildContext context) {
    if (AppMotion.reducedOf(context)) return _paintFrame(active ? 1 : 0, child);

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: active ? 1 : 0),
      duration: active ? AppMotion.focusBorderEnter : AppMotion.focusBorderExit,
      curve: active ? AppMotion.enterCurve : AppMotion.exitCurve,
      builder: (context, progress, child) => _paintFrame(progress, child),
      child: child,
    );
  }

  Widget _paintFrame(double progress, Widget? child) => DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: radius,
      boxShadow: [
        if (progress > 0)
          BoxShadow(
            color: AppPalette.focusGlow.withValues(alpha: AppPalette.focusGlow.a * progress),
            blurRadius: AppSizes.focusBlur,
          ),
      ],
    ),
    child: DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(color: Color.lerp(restingColor, color, progress) ?? restingColor, width: width),
      ),
      child: child,
    ),
  );
}
