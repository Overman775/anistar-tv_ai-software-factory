import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';

import '../../domain/models/anime_summary.dart';
import 'catalog_inspector_copy.dart';

/// The catalog owns dwell and its two text buffers; focus never fetches details.
class CatalogInspector extends StatefulWidget {
  const CatalogInspector({required this.anime, super.key});

  final AnimeSummary anime;

  @override
  State<CatalogInspector> createState() => _CatalogInspectorState();
}

class _CatalogInspectorState extends State<CatalogInspector> {
  late AnimeSummary _first = widget.anime;
  late AnimeSummary _second = widget.anime;
  bool _showSecond = false;
  Timer? _dwell;
  Timer? _settle;

  void _update() {
    if (!mounted) {
      return;
    }
    _settle?.cancel();
    setState(() {
      if (_showSecond) {
        _first = widget.anime;
      } else {
        _second = widget.anime;
      }
      _showSecond = !_showSecond;
    });
    _settle = Timer(AppMotion.inspectorContent, _finishTransition);
  }

  void _finishTransition() {
    if (!mounted) {
      return;
    }
    // Release the outgoing height after the fade, without animating layout.
    setState(() {
      if (_showSecond) {
        _first = _second;
      } else {
        _second = _first;
      }
    });
  }

  @override
  void didUpdateWidget(covariant CatalogInspector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identical(oldWidget.anime, widget.anime)) {
      return;
    }
    _dwell?.cancel();
    if (AppMotion.reducedOf(context)) {
      _settle?.cancel();
      if (_showSecond) {
        _first = widget.anime;
      } else {
        _second = widget.anime;
      }
      _showSecond = !_showSecond;
    } else {
      _dwell = Timer(AppMotion.inspectorDwell, _update);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AppMotion.reducedOf(context)) {
      _dwell?.cancel();
      _settle?.cancel();
      _first = widget.anime;
      _second = widget.anime;
    }
  }

  @override
  void dispose() {
    _dwell?.cancel();
    _settle?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (AppMotion.reducedOf(context)) {
      return CatalogInspectorCopy(anime: widget.anime);
    }

    // Both text buffers determine the natural height. Tight intrinsic bounds
    // keep AnimatedCrossFade's AnimatedSize from moving the grid during a fade.
    return IntrinsicHeight(
      child: AnimatedCrossFade(
        duration: AppMotion.durationOf(context, AppMotion.inspectorContent),
        reverseDuration: AppMotion.durationOf(context, AppMotion.inspectorContent),
        firstCurve: const Interval(0, 0.5, curve: Curves.easeInCubic),
        secondCurve: const Interval(0.5, 1, curve: Curves.easeOutCubic),
        crossFadeState: _showSecond ? CrossFadeState.showSecond : CrossFadeState.showFirst,
        firstChild: ExcludeSemantics(
          excluding: _showSecond,
          child: CatalogInspectorCopy(anime: _first),
        ),
        secondChild: ExcludeSemantics(
          excluding: !_showSecond,
          child: CatalogInspectorCopy(anime: _second),
        ),
        layoutBuilder: (top, topKey, bottom, bottomKey) => Stack(
          alignment: Alignment.topLeft,
          children: [
            KeyedSubtree(key: bottomKey, child: bottom),
            KeyedSubtree(key: topKey, child: top),
          ],
        ),
      ),
    );
  }
}
