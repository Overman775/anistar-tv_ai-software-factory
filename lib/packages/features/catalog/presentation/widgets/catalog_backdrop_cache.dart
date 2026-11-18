import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:app_logging/app_logging.dart';
import 'package:material_ui/material_ui.dart';

/// Holds the prepared poster textures for one TV inspector.
class CatalogBackdropCache {
  static const _textureHeight = 240;
  static const _capacity = 24;

  final _ready = <ImageProvider<Object>, ui.Image>{};
  final _pending = <ImageProvider<Object>, Future<void>>{};
  ui.FragmentShader? _fadeShader;
  bool _disposed = false;

  ui.FragmentShader? get fadeShader => _fadeShader;

  /// The caller owns the returned handle independently of the cache.
  Future<ui.Image?> acquire(ImageProvider<Object> provider, ImageConfiguration configuration) async {
    if (_disposed) return null;
    if (!_ready.containsKey(provider)) {
      await _pending.putIfAbsent(provider, () => _prepare(provider, configuration));
    }
    final image = _ready.remove(provider);
    if (image == null) return null;

    _ready[provider] = image;
    return image.clone();
  }

  Future<void> _prepare(ImageProvider<Object> provider, ImageConfiguration configuration) async {
    try {
      final source = await _decode(provider.resolve(configuration));
      if (source == null) return;
      try {
        if (_disposed) return;
        final fadeProgram = await ui.FragmentProgram.fromAsset('shaders/catalog_poster_fade.frag');
        if (_disposed) return;
        _fadeShader ??= fadeProgram.fragmentShader();
        final prepared = await _blur(source.image);
        if (_disposed) {
          prepared.dispose();
          return;
        }

        _ready[provider] = prepared;
        if (_ready.length > _capacity) _ready.remove(_ready.keys.first)?.dispose();
      } finally {
        source.dispose();
      }
    } on Exception {
      AppLogger.logger.warningFor<CatalogBackdropCache>('Could not prepare the TV poster backdrop');
    } finally {
      unawaited(_pending.remove(provider));
    }
  }

  Future<ImageInfo?> _decode(ImageStream stream) {
    final result = Completer<ImageInfo?>();
    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (info, _) {
        stream.removeListener(listener);
        result.complete(info);
      },
      onError: (_, _) {
        stream.removeListener(listener);
        result.complete(null);
      },
    );
    stream.addListener(listener);
    return result.future;
  }

  Future<ui.Image> _blur(ui.Image source) async {
    final program = await ui.FragmentProgram.fromAsset('shaders/catalog_poster_blur.frag');
    final width = math.max(1, (_textureHeight * source.width / source.height).round());
    final shader = program.fragmentShader()
      ..setFloat(0, width.toDouble())
      ..setFloat(1, _textureHeight.toDouble())
      ..setImageSampler(0, source, filterQuality: ui.FilterQuality.low);
    final recorder = ui.PictureRecorder();
    final bounds = Rect.fromLTWH(0, 0, width.toDouble(), _textureHeight.toDouble());
    Canvas(recorder, bounds).drawRect(bounds, Paint()..shader = shader);
    final picture = recorder.endRecording();
    try {
      return await picture.toImage(width, _textureHeight);
    } finally {
      picture.dispose();
      shader.dispose();
    }
  }

  void dispose() {
    _disposed = true;
    for (final image in _ready.values) {
      image.dispose();
    }
    _ready.clear();
    _fadeShader?.dispose();
    _fadeShader = null;
  }
}
