import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

typedef TvFocusBuilder = Widget Function(BuildContext context, bool focused);
typedef TvFocusStateBuilder = Widget Function(BuildContext context, TvFocusState state);

/// A remote-friendly focus target that keeps activation and visual focus in sync.
class TvFocusable extends StatefulWidget {
  const TvFocusable({
    required this.onPressed,
    this.builder,
    this.stateBuilder,
    super.key,
    this.autofocus = false,
    this.enabled = true,
    this.busy = false,
    this.focusNode,
    this.onFocusChanged,
    this.onLongPressed,
    this.semanticLabel,
  }) : assert(builder != null || stateBuilder != null, 'Provide builder or stateBuilder.');

  final bool autofocus;
  final bool enabled;
  final bool busy;
  final FocusNode? focusNode;
  final TvFocusBuilder? builder;
  final TvFocusStateBuilder? stateBuilder;
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
  bool _pressed = false;
  bool _hovered = false;
  bool get _canActivate => widget.enabled && !widget.busy;
  LogicalKeyboardKey? _heldKey;
  LogicalKeyboardKey? _consumedKey;

  @override
  void initState() {
    super.initState();
    _ownedFocusNode.debugLabel = widget.semanticLabel;
  }

  void _setPressed(bool pressed) {
    if (_pressed != pressed) {
      setState(() => _pressed = pressed);
    }
  }

  void _onFocusChange(bool focused) {
    if (_focused == focused) {
      return;
    }
    setState(() {
      _focused = focused;
      if (!focused) {
        _pressed = false;
      }
    });
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
    if (!_canActivate) {
      _cancelHold();

      return KeyEventResult.handled;
    }
    if (event is KeyUpEvent) {
      _setPressed(false);
    }
    if (event is KeyRepeatEvent) {
      if (key == _heldKey && widget.onLongPressed != null) {
        _heldKey = null;
        _setPressed(false);
        _consumedKey = key;
        FocusManager.instance.addEarlyKeyEventHandler(_consumeHold);
        widget.onLongPressed?.call();
      }

      return KeyEventResult.handled;
    }
    if (event is KeyDownEvent) {
      _setPressed(true);
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
    if (!_canActivate) {
      return;
    }
    _cancelHold();
    _setPressed(false);
    _focusNode.requestFocus();
    widget.onLongPressed?.call();
  }

  void _onTap() {
    if (!_canActivate) {
      return;
    }
    _cancelHold();
    _setPressed(false);
    _focusNode.requestFocus();
    widget.onPressed();
  }

  void _setHovered(bool hovered) {
    if (_hovered != hovered) {
      setState(() => _hovered = hovered);
    }
  }

  @override
  void didUpdateWidget(TvFocusable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_canActivate) {
      _cancelHold();
      _pressed = false;
      _hovered = false;
    }
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
    canRequestFocus: widget.enabled,
    focusNode: _focusNode,
    onFocusChange: _onFocusChange,
    onKeyEvent: _onKeyEvent,
    child: Semantics(
      button: true,
      focused: _focused,
      enabled: _canActivate,
      value: widget.busy ? 'Выполняется' : null,
      onTap: _canActivate ? _onTap : null,
      label: widget.semanticLabel,
      child: MouseRegion(
        cursor: _canActivate ? SystemMouseCursors.click : SystemMouseCursors.basic,
        onEnter: _canActivate ? (_) => _setHovered(true) : null,
        onExit: (_) => _setHovered(false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          excludeFromSemantics: true,
          onTapDown: _canActivate ? (_) => _setPressed(true) : null,
          onTapUp: _canActivate ? (_) => _setPressed(false) : null,
          onTapCancel: _canActivate ? () => _setPressed(false) : null,
          onTap: _canActivate ? _onTap : null,
          onLongPress: _canActivate && widget.onLongPressed != null ? _onLongPress : null,
          child: switch ((widget.stateBuilder, widget.builder)) {
            (final stateBuilder?, _) => stateBuilder(
              context,
              TvFocusState(
                focused: _focused,
                hovered: _hovered,
                pressed: _pressed,
                enabled: widget.enabled,
                busy: widget.busy,
              ),
            ),
            (_, final builder?) => builder(context, _focused),
            _ => throw StateError('Provide builder or stateBuilder.'),
          },
        ),
      ),
    ),
  );
}

/// Presentation state, independent of the caller's selected or watched status.
@immutable
final class TvFocusState {
  final bool focused;
  final bool hovered;
  final bool pressed;
  final bool enabled;
  final bool busy;

  const TvFocusState({
    required this.focused,
    required this.hovered,
    required this.pressed,
    required this.enabled,
    required this.busy,
  });
}
