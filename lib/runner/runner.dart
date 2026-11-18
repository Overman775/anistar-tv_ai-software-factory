import 'dart:async';

import 'package:anistar/html.dart';
import 'package:app_logging/app_logging.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:networking/networking.dart';
import 'package:storage/storage.dart';
import 'package:ui_kit/ui_kit.dart';

import '../app/app.dart';
import '../app/app_config.dart';
import '../app/app_container.dart';
import '../app/app_device_profile_resolver.dart';

/// Application entry point that initializes services and runs the app.
Future<void> runApplication({
  Logger? logger,
  List<Override> overrides = const [],
  AppDeviceProfile? deviceProfile,
  bool recoverStartup = false,
}) async {
  final started = Completer<void>();
  var runtimeLogger = logger;
  // A Future failing inside a guarded error zone cannot forward its error to
  // an await in the caller's zone. Complete an explicit startup result there.
  unawaited(
    runZonedGuarded(
      () async {
        Future<void> bootstrap() async {
          WidgetsFlutterBinding.ensureInitialized();
          final appLogger = runtimeLogger ??= AppLogger.init(
            isDevelopment: !const bool.fromEnvironment('dart.vm.product'),
          );
          if (logger != null) {
            AppLogger.installErrorHandlers(appLogger);
          }
          Bloc.observer = AppBlocObserver(appLogger);
          appLogger.infoFor<Runner>('Starting application');

          final profile = deviceProfile ?? await AppDeviceProfileResolver.resolve();
          await SystemChrome.setPreferredOrientations(
            profile == AppDeviceProfile.tv ? [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight] : [],
          );
          await SystemChrome.setEnabledSystemUIMode(
            profile == AppDeviceProfile.tv ? SystemUiMode.manual : SystemUiMode.edgeToEdge,
            overlays: profile == AppDeviceProfile.tv ? [] : null,
          );

          final sharedPreferencesStorage = SharedPreferencesStorage(logger: appLogger);
          await sharedPreferencesStorage.init();

          final secureStorage = SecureStorage(logger: appLogger);
          final mirrorManager = AnistarMirrorManager(
            initial: AnistarMirrorConfig.baseUri,
            storage: sharedPreferencesStorage,
            probe: DioClient.create(
              config: NetworkConfig(
                baseUri: AnistarMirrorConfig.baseUri,
                connectTimeout: const Duration(seconds: 4),
                receiveTimeout: const Duration(seconds: 4),
                sendTimeout: const Duration(seconds: 4),
                loggablePaths: AppConfig.networkLoggablePaths,
              ),
              logger: appLogger,
              enableRetry: false,
            ),
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
              child: AppResponsiveRoot(profile: profile, child: const App()),
            ),
          );
          appLogger.infoFor<Runner>('Application mounted');
        }

        try {
          await bootstrap();
        } on Object catch (error, stackTrace) {
          if (!recoverStartup) rethrow;
          AppLogger.reportUnhandled(error, stackTrace, logger: runtimeLogger);
          runApp(_StartupFailureApp(retry: bootstrap));
        }
        started.complete();
      },
      (error, stackTrace) {
        AppLogger.reportUnhandled(error, stackTrace, logger: runtimeLogger);
        if (!started.isCompleted) {
          started.completeError(error, stackTrace);
        }
      },
    ),
  );
  await started.future;
}

class _StartupFailureApp extends StatefulWidget {
  const _StartupFailureApp({required this.retry});

  final Future<void> Function() retry;

  @override
  State<_StartupFailureApp> createState() => _StartupFailureAppState();
}

class _StartupFailureAppState extends State<_StartupFailureApp> {
  bool _retrying = false;

  Future<void> _retry() async {
    if (_retrying) return;
    _retrying = true;
    try {
      await widget.retry();
    } on Object catch (error, stackTrace) {
      AppLogger.reportUnhandled(error, stackTrace);
      _retrying = false;
    }
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    home: Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Не удалось запустить приложение.'),
                ElevatedButton(autofocus: true, onPressed: () => unawaited(_retry()), child: const Text('Повторить')),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

final class Runner {}
