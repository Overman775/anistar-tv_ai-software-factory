import 'package:material_ui/material_ui.dart';

import '../theme/app_palette.dart';
import 'app_icon.dart';

/// A passive confirmed-favorite marker that attaches to the poster's top edge.
class MediaCardBookmark extends StatelessWidget {
  const MediaCardBookmark({super.key});

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox(
      width: 36,
      height: 48,
      child: CustomPaint(
        painter: _BookmarkPainter(),
        child: const Padding(
          padding: EdgeInsets.fromLTRB(8, 8, 8, 20),
          child: Center(child: AppIcon(AppIconType.heart, color: AppPalette.textPrimary, size: 20)),
        ),
      ),
    ),
  );
}

class _BookmarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height - 6)
      ..quadraticBezierTo(size.width, size.height - 1, size.width - 4, size.height - 3)
      ..lineTo(size.width / 2 + 2, size.height - 9)
      ..quadraticBezierTo(size.width / 2, size.height - 10, size.width / 2 - 2, size.height - 9)
      ..lineTo(4, size.height - 3)
      ..quadraticBezierTo(0, size.height - 1, 0, size.height - 6)
      ..close();

    canvas.drawPath(path, Paint()..color = AppPalette.favoriteRibbon);
  }

  @override
  bool shouldRepaint(covariant _BookmarkPainter oldDelegate) => false;
}
