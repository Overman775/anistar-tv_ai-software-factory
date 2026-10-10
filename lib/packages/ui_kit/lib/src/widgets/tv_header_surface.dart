import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';

class TvHeaderSurface extends StatelessWidget {
  const TvHeaderSurface({super.key});

  @override
  Widget build(BuildContext context) => ClipRect(
    child: BackdropFilter(
      filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
      child: const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0x8C24183D), Color(0x730D1220)],
          ),
          border: Border(bottom: BorderSide(color: Color(0x267C3AED))),
        ),
        child: SizedBox.expand(),
      ),
    ),
  );
}
