import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

typedef TvFocusBuilder = Widget Function(BuildContext context, bool focused);

/// A remote-friendly focus target that keeps activation and visual focus in sync.
class TvFocusable extends StatefulWidget {
  const TvFocusable({
    required this.builder,
    required this.onPressed,
    super.key,
    this.autofocus = false,
    this.focusNode,
    this.onFocusChanged,
    this.onLongPressed,
    this.semanticLabel,
  });

  final bool autofocus;
  final FocusNode? focusNode;
  final TvFocusBuilder builder;
  final ValueChanged<bool>? onFocusChanged;
  final VoidCallback? onLongPressed;
  final VoidCallback onPressed;
  final String? semanticLabel;

  @override
  State<TvFocusable> createState() => _TvFocusableState();
}

class _TvFocusableState extends State<TvFocusable> {
  final FocusNode _ownedFocusNode = FocusNode();
  FocusNode get _focusNode => widget.focusNode ?? _ownedFocusNode;
  bool _focused = false;
  LogicalKeyboardKey? _heldKey;
  LogicalKeyboardKey? _consumedKey;

  @override
  void initState() {
    super.initState();
    _ownedFocusNode.debugLabel = widget.semanticLabel;
  }

  void _onFocusChange(bool focused) {
    if (_focused == focused) {
      return;
    }
    setState(() => _focused = focused);
    if (!focused) {
      _cancelHold();
    }
    widget.onFocusChanged?.call(focused);
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    final key = event.logicalKey;
    final activates =
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.space ||
        key == LogicalKeyboardKey.gameButtonA;
    if (!activates) {
      return KeyEventResult.ignored;
    }
    if (event is KeyRepeatEvent) {
      if (key == _heldKey && widget.onLongPressed != null) {
        _heldKey = null;
        _consumedKey = key;
        FocusManager.instance.addEarlyKeyEventHandler(_consumeHold);
        widget.onLongPressed?.call();
      }

      return KeyEventResult.handled;
    }
    if (event is KeyDownEvent) {
      if (widget.onLongPressed == null) {
        widget.onPressed();
      } else {
        _heldKey ??= key;
      }

      return KeyEventResult.handled;
    }
    if (event is KeyUpEvent && key == _heldKey) {
      _cancelHold();
      widget.onPressed();

      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  // The panel takes focus while OK is still held. Consume the rest of this
  // key sequence before it reaches the newly focused action.
  KeyEventResult _consumeHold(KeyEvent event) {
    if (event.logicalKey != _consumedKey) {
      return KeyEventResult.ignored;
    }
    if (event is KeyUpEvent) {
      _consumedKey = null;
      FocusManager.instance.removeEarlyKeyEventHandler(_consumeHold);
    }

    return KeyEventResult.handled;
  }

  void _cancelHold() {
    _heldKey = null;
  }

  void _onLongPress() {
    _cancelHold();
    _focusNode.requestFocus();
    widget.onLongPressed?.call();
  }

  void _onTap() {
    _cancelHold();
    _focusNode.requestFocus();
    widget.onPressed();
  }

  @override
  void dispose() {
    _cancelHold();
    FocusManager.instance.removeEarlyKeyEventHandler(_consumeHold);
    _ownedFocusNode.dispose();
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
          onLongPress: widget.onLongPressed == null ? null : _onLongPress,
          child: widget.builder(context, _focused),
        ),
      ),
    ),
  );
}
