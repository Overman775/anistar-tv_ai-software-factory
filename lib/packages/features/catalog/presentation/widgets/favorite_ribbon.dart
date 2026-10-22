import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';

/// Decoration denotes confirmed status and never adds a separate action.
class FavoriteRibbon extends StatelessWidget {
  const FavoriteRibbon({super.key});

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'В избранном',
    child: const SizedBox(
      width: 30,
      height: 40,
      child: CustomPaint(
        painter: _RibbonPainter(),
        child: Align(alignment: Alignment(0, -0.55), child: AppIcon(AppIconType.heart, size: 18)),
      ),
    ),
  );
}

class _RibbonPainter extends CustomPainter {
  const _RibbonPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(size.width / 2, size.height * 0.78)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = AppPalette.favoriteRibbon);
  }

  @override
  bool shouldRepaint(covariant _RibbonPainter oldDelegate) => false;
}
