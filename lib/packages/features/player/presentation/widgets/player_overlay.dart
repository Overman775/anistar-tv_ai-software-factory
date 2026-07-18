import 'package:flutter/material.dart';
import 'package:ui_kit/ui_kit.dart';
import 'package:video_player/video_player.dart';

import '../../domain/models/playback_session.dart';

class PlayerOverlay extends StatelessWidget {
  const PlayerOverlay({
    required this.title,
    required this.episodeNumber,
    required this.session,
    required this.value,
    required this.onPlayPause,
    required this.onSeek,
    super.key,
  });

  static String _format(Duration value) {
    final hours = value.inHours;
    final minutes = value.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');

    return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
  }

  final int episodeNumber;
  final VoidCallback onPlayPause;
  final ValueChanged<Duration> onSeek;
  final PlaybackSession session;
  final String title;
  final VideoPlayerValue value;

  void _onSliderChanged(double milliseconds) => onSeek(Duration(milliseconds: milliseconds.round()));

  void _seekBackward() => _seekRelative(const Duration(seconds: -10));

  void _seekForward() => _seekRelative(const Duration(seconds: 10));

  void _seekRelative(Duration offset) {
    final target = value.position + offset;
    final durationMs = value.duration.inMilliseconds;
    onSeek(Duration(milliseconds: target.inMilliseconds.clamp(0, durationMs)));
  }

  @override
  Widget build(BuildContext context) {
    final durationMs = value.duration.inMilliseconds;
    final positionMs = value.position.inMilliseconds.clamp(0, durationMs == 0 ? 1 : durationMs);

    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xC9000000), Color(0x00000000), Color(0xE8000000)],
          stops: [0, 0.48, 1],
        ),
      ),
      child: SafeArea(
        minimum: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: Colors.white),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Серия $episodeNumber • ${session.selectedQuality.apiValue}p',
              style: const TextStyle(color: AppPalette.textSecondary),
            ),
            const Spacer(),
            DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xB8141B2D),
                borderRadius: AppRadii.large,
                border: Border.fromBorderSide(BorderSide(color: Colors.white.withValues(alpha: 0.12))),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
                child: Column(
                  children: [
                    Row(
                      children: [
                        IconButton(
                          iconSize: 30,
                          onPressed: _seekBackward,
                          tooltip: 'Назад на 10 секунд',
                          icon: const Icon(Icons.replay_10_rounded),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        IconButton.filled(
                          iconSize: 38,
                          onPressed: onPlayPause,
                          tooltip: value.isPlaying ? 'Пауза' : 'Воспроизвести',
                          icon: Icon(value.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        IconButton(
                          iconSize: 30,
                          onPressed: _seekForward,
                          tooltip: 'Вперёд на 10 секунд',
                          icon: const Icon(Icons.forward_10_rounded),
                        ),
                        const SizedBox(width: AppSpacing.lg),
                        Text(_format(value.position), style: const TextStyle(color: Colors.white)),
                        Expanded(
                          child: Slider(
                            value: positionMs.toDouble(),
                            max: durationMs <= 0 ? 1 : durationMs.toDouble(),
                            onChanged: _onSliderChanged,
                          ),
                        ),
                        Text(_format(value.duration), style: const TextStyle(color: Colors.white)),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    const Row(
                      children: [
                        Icon(Icons.gamepad_outlined, size: 20, color: AppPalette.textSecondary),
                        SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            '←/→  перемотка 10 секунд     OK  пауза или воспроизведение',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: AppPalette.textSecondary),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
