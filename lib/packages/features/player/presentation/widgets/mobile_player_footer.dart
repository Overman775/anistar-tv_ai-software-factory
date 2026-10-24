import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';
import 'package:video_player/video_player.dart';

import 'player_control_button.dart';
import 'player_progress.dart';

class MobilePlayerFooter extends StatelessWidget {
  const MobilePlayerFooter({
    required this.value,
    required this.onSeek,
    this.onPreviousEpisode,
    this.onNextEpisode,
    this.onInteractionStart,
    this.onInteractionEnd,
    super.key,
  });

  final VideoPlayerValue value;
  final ValueChanged<Duration> onSeek;
  final VoidCallback? onPreviousEpisode;
  final VoidCallback? onNextEpisode;
  final VoidCallback? onInteractionStart;
  final VoidCallback? onInteractionEnd;

  @override
  Widget build(BuildContext context) {
    final durationMs = playerSliderMaximum(value.duration);
    final position = playerSliderPosition(value.position, value.duration);
    final buffered = playerBufferedPosition(value.buffered, value.duration);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 3,
            activeTrackColor: AppPalette.primary,
            inactiveTrackColor: AppPalette.playerMuted.withValues(alpha: 0.3),
            secondaryActiveTrackColor: AppPalette.playerMuted.withValues(alpha: 0.6),
            thumbColor: AppPalette.primary,
            padding: EdgeInsets.zero,
          ),
          child: Slider(
            key: const ValueKey('player-timeline'),
            value: position.toDouble(),
            max: durationMs.toDouble(),
            secondaryTrackValue: buffered.toDouble(),
            onChangeStart: (_) => onInteractionStart?.call(),
            onChangeEnd: (_) => onInteractionEnd?.call(),
            onChanged: value.duration.inMilliseconds > 0
                ? (milliseconds) => onSeek(Duration(milliseconds: milliseconds.round()))
                : null,
            semanticFormatterCallback: (milliseconds) => formatPlayerTime(Duration(milliseconds: milliseconds.round())),
          ),
        ),
        Row(
          children: [
            if (onPreviousEpisode != null) ...[
              PlayerControlButton(
                buttonKey: 'player-previous-episode',
                label: 'Предыдущая серия',
                onPressed: onPreviousEpisode,
                child: const AppIcon(AppIconType.skipBack),
              ),
              const SizedBox(width: AppSpacing.sm),
            ],
            if (onNextEpisode != null) ...[
              PlayerControlButton(
                buttonKey: 'player-next-episode',
                label: 'Следующая серия',
                onPressed: onNextEpisode,
                child: const AppIcon(AppIconType.skipForward),
              ),
              const SizedBox(width: AppSpacing.sm),
            ],
            Expanded(
              child: Text(
                '${formatPlayerTime(Duration(milliseconds: position))} / ${formatPlayerTime(value.duration)}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                style: Theme.of(context).textTheme.bodyLarge
                    ?.copyWith(color: AppPalette.playerText, fontFeatures: const [FontFeature.tabularFigures()]),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
