import 'package:material_ui/material_ui.dart';

import '../theme/app_palette.dart';
import 'app_icon.dart';

/// A passive confirmed-favorite marker that attaches to the poster's top edge.
class MediaCardBookmark extends StatelessWidget {
  const MediaCardBookmark({
    super.key,
    this.width = 36,
    this.height = 48,
    this.iconSize = 28,
    this.inset = 4,
    this.notch = 6,
    this.padding = const EdgeInsets.fromLTRB(4, 8, 4, 12),
  });

  final double width;
  final double height;
  final double iconSize;
  final EdgeInsets padding;

  /// Horizontal inset of the bookmark contour.
  final double inset;

  /// Depth of the lower notch.
  final double notch;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox(
      width: width,
      height: height,
      child: CustomPaint(
        painter: _BookmarkPainter(inset: inset, notch: notch),
        child: Padding(
          padding: padding,
          child: Center(
            child: AppIcon(AppIconType.heart, color: AppPalette.textPrimary, size: iconSize),
          ),
        ),
      ),
    ),
  );
}

class _BookmarkPainter extends CustomPainter {
  const _BookmarkPainter({required this.inset, required this.notch});

  final double inset;
  final double notch;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height - notch)
      ..quadraticBezierTo(size.width, size.height - 1, size.width - inset, size.height - notch / 2)
      ..lineTo(size.width / 2 + 2, size.height - notch - 3)
      ..quadraticBezierTo(size.width / 2, size.height - notch - 4, size.width / 2 - 2, size.height - notch - 3)
      ..lineTo(inset, size.height - notch / 2)
      ..quadraticBezierTo(0, size.height - 1, 0, size.height - notch)
      ..close();

    canvas.drawPath(path, Paint()..color = AppPalette.favoriteRibbon);
  }

  @override
  bool shouldRepaint(covariant _BookmarkPainter oldDelegate) =>
      inset != oldDelegate.inset || notch != oldDelegate.notch;
}
