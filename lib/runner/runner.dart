import 'dart:async';

import 'package:anistar/anistar.dart';
import 'package:app_logging/app_logging.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:storage/storage.dart';

import '../app/app.dart';
import '../app/app_container.dart';

/// Application entry point that initializes services and runs the app.
Future<void> runApplication({Logger? logger, List<Override> overrides = const []}) async {
  final started = Completer<void>();
  var runtimeLogger = logger;
  // A Future failing inside a guarded error zone cannot forward its error to
  // an await in the caller's zone. Complete an explicit startup result there.
  unawaited(
    runZonedGuarded(
      () async {
        WidgetsFlutterBinding.ensureInitialized();
        final appLogger = logger ?? AppLogger.init(isDevelopment: !const bool.fromEnvironment('dart.vm.product'));
        runtimeLogger = appLogger;
        Bloc.observer = AppBlocObserver(appLogger);
        appLogger.infoFor<Runner>('Starting application');

        await SystemChrome.setPreferredOrientations([
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);

        final sharedPreferencesStorage = SharedPreferencesStorage(logger: appLogger);
        await sharedPreferencesStorage.init();

        final secureStorage = SecureStorage(logger: appLogger);
        final mirrorManager = AnistarMirrorManager(
          initial: AnistarMirrorConfig.baseUri,
          storage: sharedPreferencesStorage,
        );
        await mirrorManager.initialize();
        final mirrorUri = mirrorManager.current;
        appLogger.infoFor<Runner>('Runtime dependencies ready; AniStar mirror: ${mirrorUri.host}');

        runApp(
          ProviderScope(
            overrides: [
              ...createAppOverrides(
                logger: appLogger,
                mirrorUri: mirrorUri,
                mirrorManager: mirrorManager,
                preferences: sharedPreferencesStorage,
                secureStorage: secureStorage,
              ),
              ...overrides,
            ],
            child: const App(),
          ),
        );
        appLogger.infoFor<Runner>('Application mounted');
        started.complete();
      },
      (error, stackTrace) {
        final appLogger = runtimeLogger;
        if (appLogger != null) {
          appLogger.e('Unhandled application exception', error: error, stackTrace: stackTrace);
        } else {
          AppLogger.reportUnhandled(error, stackTrace);
        }
        if (!started.isCompleted) {
          started.completeError(error, stackTrace);
        }
      },
    ),
  );
  await started.future;
}

final class Runner {}
