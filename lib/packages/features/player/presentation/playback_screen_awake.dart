import 'package:app_logging/app_logging.dart';
import 'package:flutter/services.dart';

/// Owns only this activity's screen flag; commands are sent in channel order.
final class PlaybackScreenAwake {
  static const _channel = MethodChannel('anistar_tv/playback_screen_awake');
  final Logger _logger;
  bool? _enabled;

  PlaybackScreenAwake(this._logger);

  Future<void> setEnabled(bool enabled) async {
    if (_enabled == enabled) {
      return;
    }
    _enabled = enabled;
    try {
      await _channel.invokeMethod<void>('setEnabled', enabled);
    } on Object {
      // A channel failure must not escape a player listener or trigger HLS retry.
      _enabled = null;
      _logger.warningFor<PlaybackScreenAwake>('Could not update playback screen flag');
    }
  }
}
