import 'package:material_ui/material_ui.dart';

import '../theme/app_palette.dart';
import 'app_network_image.dart';

/// Account image with initials retained for absent, loading and failed images.
class AppAvatar extends StatelessWidget {
  const AppAvatar({required this.name, this.imageUrl, this.size = AppSizes.touchControl, super.key});

  static String initialsOf(String name) => name
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .take(2)
      .map((part) => String.fromCharCode(part.runes.first))
      .join()
      .toUpperCase();

  final String name;
  final String? imageUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final fallback = DecoratedBox(
      decoration: const BoxDecoration(color: AppPalette.menuControl, borderRadius: AppRadii.medium),
      child: Center(
        child: Text(
          initialsOf(name),
          maxLines: 1,
          overflow: TextOverflow.clip,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(color: AppPalette.textPrimary),
        ),
      ),
    );

    return Semantics(
      label: name,
      image: true,
      child: ExcludeSemantics(
        child: SizedBox.square(
          dimension: size,
          child: AppNetworkImage(
            imageUrl: imageUrl,
            borderRadius: AppRadii.medium,
            errorWidget: fallback,
            placeholder: fallback,
            width: size,
            height: size,
          ),
        ),
      ),
    );
  }
}
