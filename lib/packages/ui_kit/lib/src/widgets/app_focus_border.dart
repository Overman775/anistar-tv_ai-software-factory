import 'package:material_ui/material_ui.dart';

import '../theme/app_palette.dart';
import 'app_focus_frame.dart';

/// Paints a constant-width frame without changing layout or delaying input.
class AppFocusBorder extends StatelessWidget {
  const AppFocusBorder({
    required this.child,
    this.focused = false,
    this.focusNode,
    this.radius = AppRadii.medium,
    this.color = AppPalette.focusOutline,
    this.restingColor = Colors.transparent,
    this.width = 2,
    super.key,
  });

  final Widget child;
  final bool focused;
  final FocusNode? focusNode;
  final BorderRadius radius;
  final Color color;
  final Color restingColor;
  final double width;

  @override
  Widget build(BuildContext context) {
    final node = focusNode;

    return node == null
        ? AppFocusFrame(
            active: focused,
            color: color,
            restingColor: restingColor,
            radius: radius,
            width: width,
            child: child,
          )
        : ListenableBuilder(
            listenable: node,
            builder: (context, _) => AppFocusFrame(
              active: node.hasFocus,
              color: color,
              restingColor: restingColor,
              radius: radius,
              width: width,
              child: child,
            ),
          );
  }
}
