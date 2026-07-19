import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:logger/logger.dart';

/// Sends BLoC lifecycle diagnostics through the application logger.
final class AppBlocObserver extends BlocObserver {
  final Logger _logger;

  AppBlocObserver(this._logger);

  @override
  // ignore: avoid-dynamic, required by BlocObserver's public API.
  void onEvent(Bloc<dynamic, dynamic> bloc, Object? event) {
    _logger.d('${bloc.runtimeType} event: $event');
    super.onEvent(bloc, event);
  }

  @override
  void onTransition(
    // ignore: avoid-dynamic, required by BlocObserver's public API.
    Bloc<dynamic, dynamic> bloc,
    // ignore: avoid-dynamic, required by BlocObserver's public API.
    Transition<dynamic, dynamic> transition,
  ) {
    _logger.d('${bloc.runtimeType} transition: $transition');
    super.onTransition(bloc, transition);
  }

  @override
  // ignore: avoid-dynamic, required by BlocObserver's public API.
  void onError(BlocBase<dynamic> bloc, Object error, StackTrace stackTrace) {
    _logger.e(
      '${bloc.runtimeType} error',
      error: error,
      stackTrace: stackTrace,
    );
    super.onError(bloc, error, stackTrace);
  }
}
