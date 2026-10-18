import 'package:material_ui/material_ui.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../theme/app_palette.dart';
import 'app_network_image.dart';

/// The same clipped image participates in both ends of a poster flight.
class TvPosterHero extends StatelessWidget {
  const TvPosterHero({
    required this.tag,
    required this.imageUrl,
    required this.semanticLabel,
    this.fallbackImageUrl,
    super.key,
  });

  final Object tag;
  final String? imageUrl;
  final String semanticLabel;
  final String? fallbackImageUrl;

  @override
  Widget build(BuildContext context) => Skeleton.ignore(
    child: HeroMode(
      enabled: !AppMotion.reducedOf(context),
      child: Hero(
        tag: tag,
        createRectTween: (begin, end) => RectTween(begin: begin, end: end),
        flightShuttleBuilder: (context, animation, direction, from, to) {
          final hero = to.widget as Hero;

          return ClipRRect(borderRadius: AppRadii.large, child: hero.child);
        },
        child: ClipRRect(
          borderRadius: AppRadii.large,
          child: AppNetworkImage(
            imageUrl: imageUrl,
            semanticLabel: semanticLabel,
            fallbackImageUrl: fallbackImageUrl,
            animateLoading: fallbackImageUrl != null && fallbackImageUrl != imageUrl,
            resizeToLayout: false,
          ),
        ),
      ),
    ),
  );
}
