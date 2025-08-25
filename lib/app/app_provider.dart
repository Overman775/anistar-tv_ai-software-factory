import 'package:anistar_tv/packages/core/services/html_parser_service.dart';
import 'package:anistar_tv/packages/core/services/jw_scraper/jw_player_scraper_service.dart';
import 'package:anistar_tv/packages/core/services/secure_storage.dart';
import 'package:anistar_tv/packages/core/services/shared_preferences_storage.dart';
import 'package:anistar_tv/utils/logger/logger.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Global dependency injection provider
class AppProvider extends StatelessWidget {
  /// Constructor
  const AppProvider({super.key, required this.sharedPreferences, required this.secureStorage, required this.child});

  final Widget child;
  final SharedPreferencesStorage sharedPreferences;
  final SecureStorage secureStorage;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<SharedPreferencesStorage>.value(value: sharedPreferences),
        Provider<SecureStorage>.value(value: secureStorage),
        Provider<HtmlParserService>(
          create: (_) => HtmlParserService(logger: logger),
          dispose: (_, service) => service.dispose(),
        ),
        Provider<JwPlayerScraperService>(
          create: (context) =>
              JwPlayerScraperService(htmlParserService: context.read<HtmlParserService>(), logger: logger),
        ),
        // Series List Feature Dependencies
      ],
      child: child,
    );
  }
}
