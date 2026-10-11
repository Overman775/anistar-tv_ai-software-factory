import 'package:flutter/widgets.dart';

import '../../assets.dart';

/// Shared brand mark. The adjacent app title provides its semantic label.
class AnistarLogo extends StatelessWidget {
  const AnistarLogo({this.size = 24, super.key});

  final double size;

  @override
  Widget build(BuildContext context) =>
      Assets.images.anistarLogo.image(width: size, height: size, fit: BoxFit.contain, excludeFromSemantics: true);
}
