import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('poster blur preserves the brightness of uniform highlights and midtones', () async {
    const size = 16;
    final bounds = ui.Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble());
    final program = await ui.FragmentProgram.fromAsset('shaders/catalog_poster_blur.frag');

    for (final level in [128, 192, 224]) {
      final sourceRecorder = ui.PictureRecorder();
      ui.Canvas(sourceRecorder).drawRect(bounds, ui.Paint()..color = ui.Color.fromARGB(255, level, level, level));
      final sourcePicture = sourceRecorder.endRecording();
      final source = await sourcePicture.toImage(size, size);
      addTearDown(sourcePicture.dispose);
      addTearDown(source.dispose);

      final shader = program.fragmentShader()
        ..setFloat(0, size.toDouble())
        ..setFloat(1, size.toDouble())
        ..setImageSampler(0, source, filterQuality: ui.FilterQuality.low);
      addTearDown(shader.dispose);
      final outputRecorder = ui.PictureRecorder();
      ui.Canvas(outputRecorder).drawRect(bounds, ui.Paint()..shader = shader);
      final picture = outputRecorder.endRecording();
      final output = await picture.toImage(size, size);
      addTearDown(picture.dispose);
      addTearDown(output.dispose);

      final pixels = await output.toByteData();
      if (pixels == null) fail('Could not read the rendered poster texture.');
      const center = 4 * (size ~/ 2 * size + size ~/ 2);
      final pixel = List.generate(4, (channel) => pixels.getUint8(center + channel));
      expect(pixel.take(3), everyElement(closeTo(level, 1)), reason: 'source level $level');
      expect(pixel.last, 255);
    }
  });
}
