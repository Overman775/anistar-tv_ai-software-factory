import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../theme/app_palette.dart';

/// The static, accent-free graphite ellipse shared by catalog surfaces.
class TvBackdrop extends StatelessWidget {
  const TvBackdrop({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.hasBoundedWidth ? constraints.maxWidth : MediaQuery.sizeOf(context).width;
      final height = constraints.hasBoundedHeight ? constraints.maxHeight : MediaQuery.sizeOf(context).height;
      final shortestSide = math.min(width, height);

      return DecoratedBox(
        decoration: BoxDecoration(
          color: AppPalette.background,
          gradient: shortestSide > 0
              ? RadialGradient(
                  center: const Alignment(0, -1.32),
                  radius: width * 0.9 / shortestSide,
                  transform: const _CatalogEllipse(),
                  colors: const [AppPalette.catalogHorizon, AppPalette.background],
                )
              : null,
        ),
        child: child,
      );
    },
  );
}

/// CSS: ellipse 90% 72% at 50% -16%, without an animated shader.
class _CatalogEllipse extends GradientTransform {
  const _CatalogEllipse();

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) {
    final ratio = bounds.width > 0 ? bounds.height * 0.8 / bounds.width : 1.0;
    final centerY = bounds.top - bounds.height * 0.16;

    return Matrix4.diagonal3Values(1, ratio, 1)..setTranslationRaw(0, centerY * (1 - ratio), 0);
  }
}
