import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';

import '../../domain/models/playback_session.dart';
import '../playback_quality_label.dart';

import 'player_control_button.dart';

class MobilePlayerTools extends StatelessWidget {
  const MobilePlayerTools({required this.session, this.onSelectEpisode, this.onSelectQuality, super.key});

  final PlaybackSession session;
  final VoidCallback? onSelectEpisode;
  final VoidCallback? onSelectQuality;

  @override
  Widget build(BuildContext context) => Wrap(
    alignment: WrapAlignment.end,
    spacing: AppSpacing.sm,
    runSpacing: AppSpacing.sm,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      if (onSelectEpisode != null)
        PlayerControlButton(
          buttonKey: 'player-episodes',
          label: 'Серии',
          onPressed: onSelectEpisode,
          child: const AppIcon(AppIconType.listVideo),
        ),
      if (onSelectQuality != null)
        PlayerControlButton(
          buttonKey: 'player-quality',
          label: 'Качество: ${session.selectedQuality.label}',
          onPressed: onSelectQuality,
          child: Text(session.selectedQuality.shortLabel),
        ),
    ],
  );
}
