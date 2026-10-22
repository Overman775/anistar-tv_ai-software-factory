import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';

import 'player_control_button.dart';

class MobilePlayerTransport extends StatelessWidget {
  const MobilePlayerTransport({
    required this.playing,
    required this.onPlayPause,
    required this.onRewind,
    required this.onForward,
    super.key,
  });

  final bool playing;
  final VoidCallback onPlayPause;
  final VoidCallback onRewind;
  final VoidCallback onForward;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      PlayerControlButton(
        buttonKey: 'player-rewind',
        label: 'Назад на 10 секунд',
        onPressed: onRewind,
        child: const AppIcon(AppIconType.rotateCcw),
      ),
      const SizedBox(width: AppSpacing.lg),
      PlayerControlButton(
        buttonKey: 'player-play',
        label: playing ? 'Пауза' : 'Воспроизвести',
        onPressed: onPlayPause,
        primary: true,
        child: AppIcon(playing ? AppIconType.pause : AppIconType.play),
      ),
      const SizedBox(width: AppSpacing.lg),
      PlayerControlButton(
        buttonKey: 'player-forward',
        label: 'Вперёд на 10 секунд',
        onPressed: onForward,
        child: const AppIcon(AppIconType.rotateCw),
      ),
    ],
  );
}
