import 'package:flutter/rendering.dart' show MatrixUtils, RenderBox, ScrollCacheExtent;
import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';

import '../../domain/models/anime_summary.dart';
import 'catalog_layout.dart';

/// TV poster geometry and continuation visibility shared by catalog and search.
class CatalogPosterRail extends StatefulWidget {
  const CatalogPosterRail({
    required this.controller,
    required this.heading,
    required this.items,
    required this.selectedId,
    required this.itemBuilder,
    required this.onKeyEvent,
    required this.active,
    this.continuationIdentity,
    this.onVisibleContinuation,
    this.unloadedCount = 0,
    this.loadingMore = false,
    this.tail,
    super.key,
  });

  final ScrollController controller;
  final Widget heading;
  final List<AnimeSummary> items;
  final int selectedId;
  final Widget Function(BuildContext, AnimeSummary, int, double) itemBuilder;
  final KeyEventResult Function(KeyEvent, double) onKeyEvent;
  final bool active;
  final Object? continuationIdentity;
  final VoidCallback? onVisibleContinuation;
  final int unloadedCount;
  final bool loadingMore;
  final Widget? tail;

  static double stepOf(BuildContext context) {
    final viewport = MediaQuery.sizeOf(context);

    return CatalogLayout.posterWidth(viewport.height) + CatalogLayout.posterGap(viewport.width);
  }

  @override
  State<CatalogPosterRail> createState() => _CatalogPosterRailState();
}

class _CatalogPosterRailState extends State<CatalogPosterRail> {
  final _viewport = GlobalKey();
  final _firstUnloaded = GlobalKey();
  Object? _requestedIdentity;
  bool _checkScheduled = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_scheduleVisibilityCheck);
  }

  @override
  void didUpdateWidget(covariant CatalogPosterRail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      oldWidget.controller.removeListener(_scheduleVisibilityCheck);
      widget.controller.addListener(_scheduleVisibilityCheck);
    }
    if (!widget.active) _requestedIdentity = null;
    _scheduleVisibilityCheck();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_scheduleVisibilityCheck);
    super.dispose();
  }

  void _scheduleVisibilityCheck() {
    if (!widget.active || _checkScheduled) return;
    _checkScheduled = true;
    WidgetsBinding.instance
      ..addPostFrameCallback((_) {
        _checkScheduled = false;
        if (!mounted || !widget.active || widget.loadingMore) return;
        final identity = widget.continuationIdentity;
        if (identity == null || identical(_requestedIdentity, identity)) return;
        final viewport = _bounds(_viewport);
        final slot = _bounds(_firstUnloaded);
        if (viewport == null || slot == null || !viewport.overlaps(slot)) return;

        _requestedIdentity = identity;
        widget.onVisibleContinuation?.call();
      })
      ..ensureVisualUpdate();
  }

  Rect? _bounds(GlobalKey key) {
    final render = key.currentContext?.findRenderObject();
    if (render is! RenderBox || !render.attached || !render.hasSize) return null;

    return MatrixUtils.transformRect(render.getTransformTo(null), Offset.zero & render.size);
  }

  @override
  Widget build(BuildContext context) {
    final viewport = MediaQuery.sizeOf(context);
    final width = CatalogLayout.posterWidth(viewport.height);
    final height = width / AppSizes.posterRatio;
    final anchor = CatalogLayout.horizontalInset(viewport.width) + CatalogLayout.focusGutter;
    final step = CatalogPosterRail.stepOf(context);
    final tail = widget.tail;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(padding: EdgeInsets.fromLTRB(anchor, 16, anchor, 8), child: widget.heading),
        SizedBox(
          key: _viewport,
          height: height + CatalogLayout.railTopPadding + CatalogLayout.railBottomPadding,
          child: LayoutBuilder(
            builder: (context, constraints) {
              _scheduleVisibilityCheck();

              return Focus(
                canRequestFocus: false,
                onKeyEvent: (_, event) => widget.onKeyEvent(event, step),
                child: Semantics(
                  container: true,
                  explicitChildNodes: true,
                  liveRegion: widget.loadingMore,
                  label: widget.loadingMore ? 'Загружаем следующую страницу' : null,
                  child: ListView.builder(
                    key: const ValueKey('tv-catalog-poster-rail'),
                    primary: false,
                    controller: widget.controller,
                    scrollDirection: Axis.horizontal,
                    physics: const NeverScrollableScrollPhysics(),
                    scrollCacheExtent: ScrollCacheExtent.pixels(step * 3),
                    padding: EdgeInsets.fromLTRB(
                      anchor,
                      CatalogLayout.railTopPadding,
                      (constraints.maxWidth - anchor - step).clamp(0.0, double.infinity),
                      CatalogLayout.railBottomPadding,
                    ),
                    itemExtent: step,
                    itemCount: widget.items.length + (tail != null ? 1 : widget.unloadedCount),
                    itemBuilder: (context, index) {
                      final anime = widget.items.elementAtOrNull(index);
                      if (anime == null) {
                        return Align(
                          alignment: Alignment.centerLeft,
                          child: SizedBox(
                            key: index == widget.items.length && tail == null ? _firstUnloaded : null,
                            width: width,
                            height: height,
                            child: tail ?? _unloadedPoster(),
                          ),
                        );
                      }
                      final selected = widget.selectedId == anime.id;

                      return Align(
                        key: ValueKey(anime.id),
                        alignment: Alignment.centerLeft,
                        child: AnimatedScale(
                          scale: selected ? 1.08 : 0.94,
                          duration: AppMotion.durationOf(
                            context,
                            selected ? AppMotion.focusBorderEnter : AppMotion.focusBorderExit,
                          ),
                          curve: selected ? AppMotion.enterCurve : AppMotion.exitCurve,
                          child: SizedBox(
                            width: width,
                            height: height,
                            child: widget.itemBuilder(context, anime, index, step),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _unloadedPoster() => ExcludeSemantics(
    child: widget.loadingMore
        ? const TvSkeletonBox(key: ValueKey('tv-catalog-loading-slot'), borderRadius: AppRadii.large)
        : const DecoratedBox(
            key: ValueKey('tv-catalog-unloaded-slot'),
            decoration: BoxDecoration(color: AppPalette.surfaceElevated, borderRadius: AppRadii.large),
          ),
  );
}
