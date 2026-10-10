import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';

/// Transfers remote focus from playback to its recovery action.
class PlayerRetryView extends StatefulWidget {
  const PlayerRetryView({
    required this.icon,
    required this.title,
    required this.message,
    required this.onRetry,
    super.key,
  });

  final IconData icon;
  final String title;
  final String message;
  final VoidCallback onRetry;

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
  Widget build(BuildContext context) => TvStateView(
    icon: widget.icon,
    title: widget.title,
    message: widget.message,
    actionLabel: 'Повторить',
    actionFocusNode: _focusNode,
    onAction: widget.onRetry,
  );
}
