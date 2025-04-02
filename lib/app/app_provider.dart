import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../packages/core/services/preferences_service.dart';
import '../packages/features/favorites/services/favorites_service.dart';
import '../packages/features/home/services/video_service.dart';

/// Global dependency injection provider
class AppProvider extends StatelessWidget {
  final Widget child;

  /// Constructor
  const AppProvider({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    // Access the preferences service from the parent provider
    final preferencesService = Provider.of<PreferencesService>(
      context,
      listen: false,
    );

    return MultiProvider(
      providers: [
        // Feature services
        Provider<VideoService>(create: (_) => VideoService()),
        Provider<FavoritesService>(
          create: (_) => FavoritesService(preferencesService),
        ),
      ],
      child: child,
    );
  }
}
