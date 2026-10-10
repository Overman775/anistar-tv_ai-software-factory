import 'package:material_ui/material_ui.dart';

import '../theme/app_palette.dart';

class TvBackdrop extends StatelessWidget {
  const TvBackdrop({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [AppPalette.backgroundElevated, AppPalette.background, Color(0xFF10091D)],
        stops: [0, 0.58, 1],
      ),
    ),
    child: Stack(
      children: [
        const Positioned(
          top: -180,
          right: -120,
          width: 420,
          height: 420,
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [Color(0x337C3AED), Color(0x007C3AED)]),
            ),
          ),
        ),
        const Positioned(
          bottom: -220,
          left: -160,
          width: 480,
          height: 480,
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [Color(0x2422D3EE), Color(0x0022D3EE)]),
            ),
          ),
        ),
        Positioned.fill(child: child),
      ],
    ),
  );
}
