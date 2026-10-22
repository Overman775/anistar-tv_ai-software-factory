import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';

import '../theme/app_palette.dart';

/// Blur is restricted to the header rectangle, never the entire page.
class TvHeaderSurface extends StatelessWidget {
  const TvHeaderSurface({super.key});

  @override
  Widget build(BuildContext context) => ClipRect(
    child: BackdropFilter(
      filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
      child: const DecoratedBox(
        decoration: BoxDecoration(
          color: AppPalette.inspector,
          border: Border(bottom: BorderSide(color: AppPalette.outline)),
        ),
        child: SizedBox.expand(),
      ),
    ),
  );
}
