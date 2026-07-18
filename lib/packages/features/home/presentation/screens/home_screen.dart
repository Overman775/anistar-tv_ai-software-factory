import 'package:anistar_tv/packages/features/catalog/domain/models/anime_summary.dart';
import 'package:anistar_tv/packages/features/catalog/presentation/screens/catalog_screen.dart';
import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.onAnimeTap});

  final ValueChanged<AnimeSummary> onAnimeTap;

  @override
  Widget build(BuildContext context) {
    return CatalogScreen(onAnimeTap: onAnimeTap);
  }
}
