import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';

/// Paints both prepared posters in a single draw with the inspector's fade.
class CatalogBackdrop extends StatefulWidget {
  const CatalogBackdrop({
    required this.shader,
    required this.incoming,
    required this.outgoing,
    required this.fade,
    super.key,
  });

  final ui.FragmentShader shader;
  final ui.Image? incoming;
  final ui.Image? outgoing;
  final Animation<double> fade;

  @override
  State<CatalogBackdrop> createState() => _CatalogBackdropState();
}

class _CatalogBackdropState extends State<CatalogBackdrop> {
  late final _progress = ValueNotifier(widget.fade.value);

  void _sync() => _progress.value = widget.fade.value;

  @override
  void initState() {
    super.initState();
    widget.fade.addListener(_sync);
  }

  @override
  void didUpdateWidget(covariant CatalogBackdrop oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.fade == widget.fade) return;
    oldWidget.fade.removeListener(_sync);
    widget.fade.addListener(_sync);
    _sync();
  }

  @override
  void dispose() {
    widget.fade.removeListener(_sync);
    _progress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: CustomPaint(painter: _BackdropPainter(widget.shader, widget.incoming, widget.outgoing, _progress)),
  );
}

class _BackdropPainter extends CustomPainter {
  _BackdropPainter(this.shader, this.incoming, this.outgoing, this.progress) : super(repaint: progress);

  final ui.FragmentShader shader;
  final ui.Image? incoming;
  final ui.Image? outgoing;
  final ValueNotifier<double> progress;

  Size _posterSize(ui.Image? image, Size bounds) => image == null
      ? Size.zero
      : applyBoxFit(BoxFit.contain, Size(image.width.toDouble(), image.height.toDouble()), bounds).destination;

  @override
  void paint(Canvas canvas, Size size) {
    final sample = incoming ?? outgoing;
    if (sample == null || size.isEmpty) return;

    final front = _posterSize(incoming, size);
    final back = _posterSize(outgoing, size);
    final width = math.max(front.width, back.width);
    shader
      ..setFloat(0, width)
      ..setFloat(1, size.height)
      ..setFloat(2, back.width)
      ..setFloat(3, back.height)
      ..setFloat(4, front.width)
      ..setFloat(5, front.height)
      ..setFloat(6, progress.value)
      ..setImageSampler(0, outgoing ?? sample, filterQuality: ui.FilterQuality.low)
      ..setImageSampler(1, incoming ?? sample, filterQuality: ui.FilterQuality.low);
    canvas
      ..save()
      ..translate(size.width - width, 0)
      ..drawRect(Rect.fromLTWH(0, 0, width, size.height), Paint()..shader = shader)
      ..restore();
  }

  @override
  bool shouldRepaint(covariant _BackdropPainter oldDelegate) =>
      shader != oldDelegate.shader ||
      incoming != oldDelegate.incoming ||
      outgoing != oldDelegate.outgoing ||
      progress != oldDelegate.progress;
}
