import 'package:flutter/material.dart';

import '../../../catalog/domain/models/anime_summary.dart';
import '../../../catalog/presentation/screens/catalog_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({required this.onAnimeTap, super.key});

  final ValueChanged<AnimeSummary> onAnimeTap;

  @override
  Widget build(BuildContext context) => CatalogScreen(onAnimeTap: onAnimeTap);
}
