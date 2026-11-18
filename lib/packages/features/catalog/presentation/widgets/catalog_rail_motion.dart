import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:material_ui/material_ui.dart';

import 'catalog_layout.dart';

/// Keeps a single clock for the TV rail while the remote updates its target.
class CatalogRailMotion {
  CatalogRailMotion(this._scroll, TickerProvider vsync) {
    _ticker = vsync.createTicker(_advance);
  }

  final ScrollController _scroll;
  late final Ticker _ticker;
  Duration _previous = Duration.zero;
  double _target = 0;
  double _step = 0;
  FocusNode? _pendingFocus;

  void focusPoster(FocusNode node) {
    cancelFocus();
    if (node.context != null) {
      node.requestFocus();
    } else {
      _pendingFocus = node;
    }
  }

  void onPosterBuilt(FocusNode node, {required bool Function() canFocus}) {
    if (_pendingFocus != node) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_pendingFocus != node) return;
      cancelFocus();
      if (node.context != null && canFocus()) node.requestFocus();
    });
  }

  void cancelFocus() => _pendingFocus = null;

  void retarget(int index, double step, {required bool animate}) {
    if (!_scroll.hasClients || !_scroll.position.hasContentDimensions) return;
    _target = index * step;
    _step = step;
    if (!animate) {
      stop();
      final position = _scroll.position;
      final target = _clampTarget(position);
      if (position.pixels != target) position.jumpTo(target);
    } else if (!_ticker.isActive && _scroll.offset != _clampTarget(_scroll.position)) {
      _previous = Duration.zero;
      _ticker.start();
    }
  }

  void reanchor(int index, double step) {
    if (!_scroll.hasClients || _scroll.position.axis != Axis.horizontal) return;
    retarget(index, step, animate: false);
  }

  double _clampTarget(ScrollPosition position) => _target.clamp(position.minScrollExtent, position.maxScrollExtent);

  void _advance(Duration elapsed) {
    if (!_scroll.hasClients || _scroll.position.axis != Axis.horizontal) {
      stop();
      return;
    }
    final position = _scroll.position;
    final target = _clampTarget(position);
    final difference = target - position.pixels;
    // Travel one poster in the usual 64 ms. When repeats outrun that pace,
    // cover the extra distance faster so the focused poster stays in reach.
    final frame = (elapsed - _previous).inMicroseconds.clamp(0, CatalogLayout.railMotion.inMicroseconds);
    _previous = elapsed;
    final fraction = frame / CatalogLayout.railMotion.inMicroseconds;
    final extraDistance = math.max(0, difference.abs() - _step);
    final movement = math.min(difference.abs(), (_step + extraDistance * 5) * fraction);
    if (movement > 0) {
      position.jumpTo(movement == difference.abs() ? target : position.pixels + movement * difference.sign);
    }
    if (position.pixels == target) stop();
  }

  void stop() => _ticker.stop();

  void dispose() => _ticker.dispose();
}
