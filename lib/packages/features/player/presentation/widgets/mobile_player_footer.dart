import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';
import 'package:video_player/video_player.dart';

import 'player_control_button.dart';

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

  static String _format(Duration value) {
    final minutes = value.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');

    return value.inHours > 0 ? '${value.inHours}:$minutes:$seconds' : '$minutes:$seconds';
  }

  final VideoPlayerValue value;
  final ValueChanged<Duration> onSeek;
  final VoidCallback? onPreviousEpisode;
  final VoidCallback? onNextEpisode;
  final VoidCallback? onInteractionStart;
  final VoidCallback? onInteractionEnd;

  @override
  Widget build(BuildContext context) {
    final durationMs = value.duration.inMilliseconds;
    final position = value.position.inMilliseconds.clamp(0, durationMs <= 0 ? 1 : durationMs);
    final buffered = value.buffered.fold<int>(0, (previous, range) {
      final end = range.end.inMilliseconds;

      return end > previous ? end : previous;
    });

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
            max: durationMs <= 0 ? 1 : durationMs.toDouble(),
            secondaryTrackValue: buffered.clamp(0, durationMs <= 0 ? 1 : durationMs).toDouble(),
            onChangeStart: (_) => onInteractionStart?.call(),
            onChangeEnd: (_) => onInteractionEnd?.call(),
            onChanged: durationMs > 0 ? (milliseconds) => onSeek(Duration(milliseconds: milliseconds.round())) : null,
            semanticFormatterCallback: (milliseconds) => _format(Duration(milliseconds: milliseconds.round())),
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
                '${_format(Duration(milliseconds: position))} / ${_format(value.duration)}',
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
