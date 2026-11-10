import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:printeasy/core/printing/raster_encoder.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('splits tall images into bounded ESC/POS raster commands', () async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.drawRect(
      const ui.Rect.fromLTWH(0, 0, 8, 25),
      ui.Paint()..color = const ui.Color(0xFF000000),
    );
    final picture = recorder.endRecording();
    final image = await picture.toImage(8, 25);
    picture.dispose();

    try {
      final bytes = await RasterEncoder.encode(image);

      // Two GS v 0 headers: 24 rows, then the remaining row.
      expect(bytes.length, 41);
      expect(bytes.sublist(0, 8), [0x1D, 0x76, 0x30, 0x00, 1, 0, 24, 0]);
      expect(bytes.sublist(8, 32), List<int>.filled(24, 0xFF));
      expect(bytes.sublist(32, 40), [0x1D, 0x76, 0x30, 0x00, 1, 0, 1, 0]);
      expect(bytes[40], 0xFF);
    } finally {
      image.dispose();
    }
  });

  test('rejects a non-positive raster chunk height', () async {
    final recorder = ui.PictureRecorder();
    final picture = recorder.endRecording();
    final image = await picture.toImage(1, 1);
    picture.dispose();

    try {
      await expectLater(
        RasterEncoder.encode(image, chunkRows: 0),
        throwsArgumentError,
      );
    } finally {
      image.dispose();
    }
  });
}
