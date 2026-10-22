import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';

import 'player_control_button.dart';

/// Transfers remote focus from playback to its recovery action.
class PlayerRetryView extends StatefulWidget {
  const PlayerRetryView({
    required this.icon,
    required this.title,
    required this.message,
    required this.onRetry,
    this.onBack,
    super.key,
  });

  final IconData icon;
  final String title;
  final String message;
  final VoidCallback onRetry;
  final VoidCallback? onBack;

  @override
  State<PlayerRetryView> createState() => _PlayerRetryViewState();
}

class _PlayerRetryViewState extends State<PlayerRetryView> {
  final _focusNode = FocusNode(debugLabel: 'Повторить видео');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = TvStateView(
      icon: widget.icon,
      title: widget.title,
      message: widget.message,
      actionLabel: 'Повторить',
      actionFocusNode: _focusNode,
      onAction: widget.onRetry,
    );
    if (AppLayoutScope.isTvOf(context) || widget.onBack == null) {
      return state;
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        state,
        Positioned(
          top: 8,
          left: 8,
          child: SafeArea(
            child: PlayerControlButton(
              buttonKey: 'player-back',
              label: 'К сериям',
              onPressed: widget.onBack,
              child: const AppIcon(AppIconType.arrowLeft),
            ),
          ),
        ),
      ],
    );
  }
}
