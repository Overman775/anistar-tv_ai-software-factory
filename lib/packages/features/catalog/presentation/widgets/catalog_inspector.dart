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
  static const _fadeOut = Duration(milliseconds: 110);
  static const _fadeIn = Duration(milliseconds: 220);

  late AnimeSummary _displayed = widget.anime;
  late final _opacity = AnimationController(vsync: this, value: 1);
  Timer? _dwell;
  final _genreFocus = <String, FocusNode>{};

  void _showCurrent() {
    _dwell?.cancel();
    _opacity.value = 1;
    _displayed = widget.anime;
  }

  Future<void> _fadeToSelection(int id) async {
    try {
      await _opacity.animateBack(0, duration: _fadeOut, curve: Curves.easeInCubic).orCancel;
    } on TickerCanceled {
      return;
    }
    if (!mounted || widget.anime.id != id) {
      return;
    }
    setState(() => _displayed = widget.anime);
    unawaited(_opacity.animateTo(1, duration: _fadeIn, curve: Curves.easeOutCubic));
  }

  @override
  void didUpdateWidget(covariant CatalogInspector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.immediate || AppMotion.reducedOf(context)) {
      _showCurrent();

      return;
    }
    if (oldWidget.anime.id == widget.anime.id) {
      if (_displayed.id == widget.anime.id) _displayed = widget.anime;

      return;
    }
    _dwell?.cancel();
    unawaited(_opacity.animateTo(1, duration: _fadeIn, curve: Curves.easeOutCubic));
    if (_displayed.id == widget.anime.id) {
      _displayed = widget.anime;

      return;
    }
    _dwell = Timer(AppMotion.inspectorDwell, () => unawaited(_fadeToSelection(widget.anime.id)));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AppMotion.reducedOf(context)) {
      _showCurrent();
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

  @override
  Widget build(BuildContext context) {
    final viewport = MediaQuery.sizeOf(context);
    final inset = CatalogLayout.horizontalInset(viewport.width) + CatalogLayout.focusGutter;
    final actions = widget.actions;
    final selectionReady = _displayed.id == widget.anime.id;
    final copy = CatalogInspectorCopy(
      anime: _displayed,
      opacity: _opacity,
      actions: actions == null
          ? null
          : ExcludeFocus(
              excluding: !selectionReady,
              child: IgnorePointer(
                ignoring: !selectionReady,
                child: Opacity(opacity: selectionReady ? 1 : 0, child: actions),
              ),
            ),
      lastGenreFocus: widget.lastGenreFocus,
      onGenreTap: selectionReady ? widget.onGenreTap : null,
      genreFocus: _genreFocus,
      onGenreTop: widget.onGenreTop,
      onGenreRight: widget.onGenreRight,
      onGenreBottom: widget.onGenreBottom,
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
        LayoutBuilder(
          builder: (context, constraints) => FadeTransition(
            opacity: _opacity,
            child: _CatalogBackdrop(imageUrl: _displayed.posterUri?.toString(), height: constraints.maxHeight),
          ),
        ),
        Column(
          children: [
            Expanded(
              child: Padding(
                padding: EdgeInsets.fromLTRB(inset, 16, inset, 0),
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
  const _CatalogBackdrop({required this.imageUrl, required this.height});

  final String? imageUrl;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null) {
      return const SizedBox.shrink();
    }

    return Align(
      alignment: Alignment.centerRight,
      child: ExcludeSemantics(
        child: ShaderMask(
          blendMode: BlendMode.dstIn,
          shaderCallback: (bounds) => const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: [0.88, 1],
            colors: [Colors.white, Colors.transparent],
          ).createShader(bounds),
          child: ShaderMask(
            blendMode: BlendMode.dstIn,
            shaderCallback: (bounds) =>
                const LinearGradient(stops: [0, 0.55], colors: [Colors.transparent, Colors.white]).createShader(bounds),
            child: ClipRect(
              child: ColorFiltered(
                colorFilter: ColorFilter.mode(Colors.black.withValues(alpha: 0.50), BlendMode.srcATop),
                child: ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                  child: AppNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.fitHeight,
                    height: height,
                    animateLoading: false,
                    placeholder: SizedBox(width: height * AppSizes.posterRatio, height: height),
                    errorWidget: const SizedBox.shrink(),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
