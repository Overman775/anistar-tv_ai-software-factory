import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';

import 'player_control_button.dart';

class MobilePlayerHeader extends StatelessWidget {
  const MobilePlayerHeader({
    required this.title,
    required this.episodeNumber,
    required this.tools,
    this.onBack,
    this.onRotate,
    super.key,
  });

  final String title;
  final int episodeNumber;
  final Widget tools;
  final VoidCallback? onBack;
  final VoidCallback? onRotate;

  @override
  Widget build(BuildContext context) {
    final landscape = MediaQuery.orientationOf(context) == Orientation.landscape;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Row(
          children: [
            if (onBack != null) ...[
              PlayerControlButton(
                buttonKey: 'player-back',
                label: 'К сериям',
                onPressed: onBack,
                child: const AppIcon(AppIconType.arrowLeft),
              ),
              const SizedBox(width: AppSpacing.sm),
            ],
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: landscape ? 1 : 2,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.titleMedium?.copyWith(color: AppPalette.playerText, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    'Серия $episodeNumber',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodyLarge?.copyWith(color: AppPalette.playerMuted),
                  ),
                ],
              ),
            ),
            if (landscape) ...[const SizedBox(width: AppSpacing.sm), tools],
            if (onRotate != null) ...[
              const SizedBox(width: AppSpacing.sm),
              PlayerControlButton(
                buttonKey: 'player-rotate',
                label: landscape ? 'Повернуть вертикально' : 'Повернуть горизонтально',
                onPressed: onRotate,
                child: const AppIcon(AppIconType.rotateSquare),
              ),
            ],
          ],
        ),
        if (!landscape) ...[const SizedBox(height: AppSpacing.sm), tools],
      ],
    );
  }
}
