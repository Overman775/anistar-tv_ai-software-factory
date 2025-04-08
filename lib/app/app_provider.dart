import 'package:anistar_tv/packages/core/services/html_parser_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../packages/core/services/preferences_service.dart';
// Removed import for VideoService

/// Global dependency injection provider
class AppProvider extends StatelessWidget {
  final Widget child;
  final SharedPreferences sharedPreferences;

  /// Constructor
  const AppProvider({super.key, required this.sharedPreferences, required this.child});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<PreferencesService>(create: (_) => PreferencesService(sharedPreferences)),
        Provider<HtmlParserService>(create: (_) => HtmlParserService()),
        // Removed Provider<VideoService>
      ],
      child: child,
    );
  }
}
