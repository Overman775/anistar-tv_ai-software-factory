import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

typedef TvFocusBuilder = Widget Function(BuildContext context, bool focused);

/// A remote-friendly focus target that keeps activation and visual focus in sync.
class TvFocusable extends StatefulWidget {
  const TvFocusable({
    required this.builder,
    required this.onPressed,
    super.key,
    this.autofocus = false,
    this.onFocusChanged,
    this.semanticLabel,
  });

  final bool autofocus;
  final TvFocusBuilder builder;
  final ValueChanged<bool>? onFocusChanged;
  final VoidCallback onPressed;
  final String? semanticLabel;

  @override
  State<TvFocusable> createState() => _TvFocusableState();
}

class _TvFocusableState extends State<TvFocusable> {
  late final FocusNode _focusNode;
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode(debugLabel: widget.semanticLabel);
  }

  void _onFocusChange(bool focused) {
    if (_focused == focused) return;
    setState(() => _focused = focused);
    widget.onFocusChanged?.call(focused);
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    final activates =
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.space ||
        key == LogicalKeyboardKey.gameButtonA;
    if (!activates) return KeyEventResult.ignored;
    widget.onPressed();

    return KeyEventResult.handled;
  }

  void _onTap() {
    _focusNode.requestFocus();
    widget.onPressed();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Focus(
    autofocus: widget.autofocus,
    focusNode: _focusNode,
    onFocusChange: _onFocusChange,
    onKeyEvent: _onKeyEvent,
    child: Semantics(
      button: true,
      focused: _focused,
      label: widget.semanticLabel,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _onTap,
          child: widget.builder(context, _focused),
        ),
      ),
    ),
  );
}
