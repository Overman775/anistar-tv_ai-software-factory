import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';

import '../../domain/models/anime_summary.dart';
import '../../domain/models/catalog_filter.dart';
import 'catalog_inspector_copy.dart';
import 'catalog_layout.dart';

/// A single displayed title drives both the inspector and its backdrop.
class CatalogInspector extends StatefulWidget {
  const CatalogInspector({
    required this.anime,
    this.immediate = false,
    this.rail,
    this.trailingInset = 0,
    this.actions,
    this.lastGenreFocus,
    this.onGenreTap,
    this.onGenreTop,
    this.onGenreRight,
    this.onGenreBottom,
    super.key,
  });

  final AnimeSummary anime;
  final bool immediate;
  final Widget? rail;
  final double trailingInset;
  final Widget? actions;
  final FocusNode? lastGenreFocus;
  final void Function(AnimeSummary, CatalogFilter)? onGenreTap;
  final ValueChanged<FocusNode>? onGenreTop;
  final ValueChanged<FocusNode>? onGenreRight;
  final VoidCallback? onGenreBottom;

  @override
  State<CatalogInspector> createState() => _CatalogInspectorState();
}

class _CatalogInspectorState extends State<CatalogInspector> with SingleTickerProviderStateMixin {
  late AnimeSummary _displayed = widget.anime;
  AnimeSummary? _outgoing;
  ImageProvider<Object>? _backdrop;
  ImageProvider<Object>? _outgoingBackdrop;
  Uri? _resolvedPoster;
  bool? _reduced;
  int _request = 0;
  Timer? _dwell;
  final _genreFocus = <String, FocusNode>{};
  late final _opacity = AnimationController(vsync: this, duration: AppMotion.inspectorContent, value: 1)
    ..addStatusListener((status) {
      if (status == AnimationStatus.completed && _outgoing != null) {
        setState(_clearOutgoing);
      }
    });
  late final _fadeIn = _opacity.drive(CurveTween(curve: Curves.easeOutCubic));
  late final _fadeOut = ReverseAnimation(_fadeIn);

  void _clearOutgoing() {
    _outgoing = null;
    _outgoingBackdrop = null;
  }

  void _requestScene({required bool immediate}) {
    _dwell?.cancel();
    final request = ++_request;
    if (immediate) {
      _clearOutgoing();
      _opacity.value = 1;
      _displayed = widget.anime;
      unawaited(_resolveScene(request, immediate: true));
    } else {
      _dwell = Timer(AppMotion.inspectorDwell, () => unawaited(_resolveScene(request, immediate: false)));
    }
  }

  Future<void> _resolveScene(int request, {required bool immediate}) async {
    final poster = widget.anime.posterUri;
    var image = _backdrop;
    if (_resolvedPoster != poster || widget.rail == null) {
      image = widget.rail == null
          ? null
          : AppNetworkImage.providerFor(
              poster?.toString(),
              cacheHeight: (MediaQuery.sizeOf(context).height * MediaQuery.devicePixelRatioOf(context)).ceil(),
            );
      if (image != null) {
        var failed = false;
        await precacheImage(image, context, onError: (_, _) => failed = true);
        if (failed) image = null;
      }
    }
    if (!mounted || request != _request) return;
    if (immediate && identical(_backdrop, image) && _resolvedPoster == poster) return;
    if (!immediate && _displayed.id == widget.anime.id && identical(_backdrop, image)) return;

    setState(() {
      if (!immediate) {
        _outgoing = _displayed;
        _outgoingBackdrop = _backdrop;
      }
      _displayed = widget.anime;
      _backdrop = image;
      _resolvedPoster = poster;
      if (!immediate) unawaited(_opacity.forward(from: 0));
    });
  }

  @override
  void didUpdateWidget(covariant CatalogInspector oldWidget) {
    super.didUpdateWidget(oldWidget);
    final changed = oldWidget.anime.id != widget.anime.id || oldWidget.anime.posterUri != widget.anime.posterUri;
    if (changed || widget.immediate && !oldWidget.immediate) {
      _requestScene(immediate: widget.immediate || _reduced == true);
    } else if (_displayed.id == widget.anime.id) {
      _displayed = widget.anime;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduced = AppMotion.reducedOf(context);
    final first = _reduced == null;
    if (_reduced != reduced) {
      _reduced = reduced;
      if (first || reduced) {
        // The first request may resolve synchronously without an image.
        _requestScene(immediate: true);
      }
    }
  }

  @override
  void dispose() {
    _dwell?.cancel();
    _opacity.dispose();
    for (final node in _genreFocus.values) {
      node.dispose();
    }
    super.dispose();
  }

  Widget _copy(AnimeSummary anime, {required bool active, required bool outgoing}) {
    final actions = widget.actions;
    final onGenreTap = widget.onGenreTap;
    Widget? copyActions;
    if (actions != null) {
      copyActions = outgoing
          ? SizedBox(height: CatalogLayout.inspectorActionMinHeight)
          : Visibility(
              visible: active,
              maintainSize: true,
              maintainAnimation: true,
              maintainState: true,
              child: actions,
            );
    }
    return CatalogInspectorCopy(
      anime: anime,
      actions: copyActions,
      lastGenreFocus: active ? widget.lastGenreFocus : null,
      onGenreTap: onGenreTap == null
          ? null
          : (anime, filter) {
              if (active && anime.id == widget.anime.id) onGenreTap(anime, filter);
            },
      genreFocus: active ? _genreFocus : null,
      onGenreTop: active ? widget.onGenreTop : null,
      onGenreRight: active ? widget.onGenreRight : null,
      onGenreBottom: active ? widget.onGenreBottom : null,
    );
  }

  Widget _visualOnly(Widget child) => ExcludeSemantics(
    child: ExcludeFocus(child: IgnorePointer(child: child)),
  );

  @override
  Widget build(BuildContext context) {
    final viewport = MediaQuery.sizeOf(context);
    final inset = CatalogLayout.horizontalInset(viewport.width) + CatalogLayout.focusGutter;
    final ready = _displayed.id == widget.anime.id;
    final current = _copy(_displayed, active: ready, outgoing: false);
    final outgoing = _outgoing;
    final copy = Stack(
      fit: StackFit.passthrough,
      children: [
        if (outgoing != null)
          Positioned.fill(
            child: FadeTransition(
              opacity: _fadeOut,
              child: _visualOnly(_copy(outgoing, active: false, outgoing: true)),
            ),
          ),
        FadeTransition(
          opacity: _fadeIn,
          alwaysIncludeSemantics: ready,
          child: ExcludeSemantics(
            excluding: !ready,
            child: ExcludeFocus(
              excluding: !ready,
              child: IgnorePointer(ignoring: !ready, child: current),
            ),
          ),
        ),
      ],
    );
    final rail = widget.rail;
    if (rail == null) {
      return ConstrainedBox(
        constraints: BoxConstraints(maxHeight: CatalogLayout.inspectorHeight(viewport.height, 1)),
        child: copy,
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        ExcludeSemantics(
          child: IgnorePointer(
            child: LayoutBuilder(
              builder: (context, constraints) => Stack(
                fit: StackFit.expand,
                children: [
                  if (_outgoingBackdrop case final image?)
                    FadeTransition(
                      opacity: _fadeOut,
                      child: _CatalogBackdrop(image: image, height: constraints.maxHeight),
                    ),
                  if (_backdrop case final image?)
                    FadeTransition(
                      opacity: _fadeIn,
                      child: _CatalogBackdrop(image: image, height: constraints.maxHeight),
                    ),
                ],
              ),
            ),
          ),
        ),
        Column(
          children: [
            Expanded(
              child: Padding(
                padding: EdgeInsets.fromLTRB(inset, CatalogLayout.inspectorTopPadding, inset, 0),
                child: Align(
                  alignment: Alignment.topLeft,
                  child: LayoutBuilder(
                    builder: (context, constraints) => SizedBox(
                      width: math.min(
                        constraints.maxWidth * 2 / 3,
                        math.max(0, constraints.maxWidth - widget.trailingInset),
                      ),
                      height: constraints.maxHeight,
                      child: copy,
                    ),
                  ),
                ),
              ),
            ),
            rail,
          ],
        ),
      ],
    );
  }
}

class _CatalogBackdrop extends StatelessWidget {
  const _CatalogBackdrop({required this.image, required this.height});

  final ImageProvider<Object> image;
  final double height;

  @override
  Widget build(BuildContext context) {
    // Clamp the blur at image edges. The shared mask starts after compositing
    // both layers, so neither layer stops abruptly at the top of the rail.
    const blur = 19.0;
    final poster = Image(image: image, height: height, fit: BoxFit.contain, excludeFromSemantics: true);
    return Align(
      alignment: Alignment.centerRight,
      child: ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (bounds) => const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: [0.86, 1],
          colors: [Colors.white, Colors.transparent],
        ).createShader(bounds),
        child: ShaderMask(
          blendMode: BlendMode.dstIn,
          shaderCallback: (bounds) => const LinearGradient(
            stops: [0, 0.48, 0.72],
            colors: [Colors.transparent, Color(0x99FFFFFF), Colors.white],
          ).createShader(bounds),
          child: ClipRect(
            child: ColorFiltered(
              colorFilter: const ColorFilter.mode(Color(0x1F000000), BlendMode.srcATop),
              child: Stack(
                children: [
                  poster,
                  Positioned.fill(
                    child: Opacity(
                      opacity: 0.64,
                      child: ImageFiltered(
                        imageFilter: ImageFilter.blur(sigmaX: blur, sigmaY: blur, tileMode: TileMode.clamp),
                        child: poster,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
