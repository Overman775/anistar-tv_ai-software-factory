import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';

class ErrorScreen extends StatelessWidget {
  const ErrorScreen({required this.text, this.onReturnHome, super.key});

  final String text;
  final VoidCallback? onReturnHome;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: TvBackdrop(
      child: TvStateView(
        icon: Icons.error_outline_rounded,
        title: 'Страница недоступна',
        message: text,
        actionLabel: 'На главную',
        actionIcon: Icons.home_rounded,
        onAction: onReturnHome,
      ),
    ),
  );
}
