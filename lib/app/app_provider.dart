import 'package:anistar_tv/packages/core/services/html_parser_service.dart';
import 'package:anistar_tv/packages/features/series_list/data/datasources/series_list_remote_datasource.dart';
import 'package:anistar_tv/packages/features/series_list/data/repositories/series_list_repository_impl.dart';
import 'package:anistar_tv/packages/features/series_list/domain/repositories/series_list_repository.dart';
import 'package:anistar_tv/packages/features/series_list/domain/usecases/get_series_list_usecase.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../packages/core/services/preferences_service.dart';

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
        // Series List Feature Dependencies
        Provider<SeriesListRemoteDatasource>(
          // Use abstract type
          create:
              (context) => SeriesListRemoteDatasourceImpl(
                // client: context.read<http.Client>(), // Removed, not needed by constructor
                htmlParserService: context.read<HtmlParserService>(),
                // Logger can be added here if a Logger provider exists
              ),
        ),
        Provider<SeriesListRepository>(
          // Use abstract type
          create:
              (context) => SeriesListRepositoryImpl(
                remoteDatasource: context.read<SeriesListRemoteDatasource>(), // Correct parameter name
                htmlParserService: context.read<HtmlParserService>(), // Add missing parameter
                // Logger can be added here
              ),
        ),
        Provider<GetSeriesListUseCase>(
          create:
              (context) => GetSeriesListUseCase(
                context.read<SeriesListRepository>(), // Pass repository positionally
              ),
        ),
      ],
      child: child,
    );
  }
}
