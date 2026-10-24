import 'package:material_ui/material_ui.dart';

import '../theme/app_palette.dart';
import 'app_focus_border.dart';

/// Visual frame for feature-owned text fields.
///
/// Controllers, validation and keyboard behaviour remain with the caller.
class AppInputFrame extends StatelessWidget {
  const AppInputFrame({required this.child, super.key, this.focusNode, this.hasError = false});

  final Widget child;
  final FocusNode? focusNode;
  final bool hasError;

  @override
  Widget build(BuildContext context) => AppFocusBorder(
    focusNode: focusNode,
    color: hasError ? AppPalette.danger : AppPalette.focusOutline,
    restingColor: hasError ? AppPalette.danger : AppPalette.outline,
    child: child,
  );
}
