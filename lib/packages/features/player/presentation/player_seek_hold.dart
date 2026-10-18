import 'dart:async';

import 'package:flutter/services.dart';

/// Owns repeat timing so remote key-repeat frequency cannot change seek speed.
final class PlayerSeekHold {
  final void Function(Duration) onSeek;
  final void Function()? onRelease;
  final void Function()? onCancel;

  Timer? _timer;
  LogicalKeyboardKey? _key;

  bool get isActive => _key != null;

  PlayerSeekHold(this.onSeek, {this.onRelease, this.onCancel});

  bool handle(KeyEvent event) {
    final key = event.logicalKey;
    if (key != LogicalKeyboardKey.arrowLeft && key != LogicalKeyboardKey.arrowRight) {
      return false;
    }
    if (event is KeyUpEvent) {
      if (key == _key) {
        _clear();
        onRelease?.call();
      }
    } else if (event is KeyDownEvent && key != _key) {
      _clear();
      _key = key;
      final direction = key == LogicalKeyboardKey.arrowRight ? 1 : -1;
      onSeek(Duration(seconds: direction * 10));
      _timer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
        if (!identical(timer, _timer) || key != _key) {
          return;
        }
        final seconds = switch (timer.tick) {
          < 4 => 10,
          < 8 => 20,
          < 12 => 30,
          < 16 => 60,
          _ => 120,
        };
        onSeek(Duration(seconds: direction * seconds));
      });
    }

    return true;
  }

  void stop() {
    final wasActive = isActive;
    _clear();
    if (wasActive) {
      onCancel?.call();
    }
  }

  void _clear() {
    _timer?.cancel();
    _timer = null;
    _key = null;
  }
}
