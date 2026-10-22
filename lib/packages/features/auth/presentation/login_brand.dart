import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';

class LoginBrand extends StatelessWidget {
  const LoginBrand({required this.vertical, super.key});

  final bool vertical;

  @override
  Widget build(BuildContext context) {
    final label = Text.rich(
      const TextSpan(
        text: 'AniStar ',
        children: [
          TextSpan(
            text: 'TV',
            style: TextStyle(color: AppPalette.primary),
          ),
        ],
      ),
      style: Theme.of(context).textTheme.headlineMedium,
    );

    return vertical
        ? Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const AnistarLogo(size: 160),
              const SizedBox(height: AppSpacing.lg),
              label,
            ],
          )
        : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const AnistarLogo(size: 64),
              const SizedBox(width: AppSpacing.md),
              Flexible(child: label),
            ],
          );
  }
}
