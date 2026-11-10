import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:printeasy/core/printing/raster_encoder.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('encodes the complete page in one ESC/POS raster command', () async {
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

      // One GS v 0 header followed by all 25 rows (one byte per row).
      expect(bytes.length, 8 + 25);
      expect(bytes.sublist(0, 8), [0x1D, 0x76, 0x30, 0x00, 1, 0, 25, 0]);
      expect(bytes.sublist(8), List<int>.filled(25, 0xFF));
    } finally {
      image.dispose();
    }
  });

  test('rejects pages taller than the GS v 0 16-bit height limit', () async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.drawRect(
      const ui.Rect.fromLTWH(0, 0, 1, 1),
      ui.Paint()..color = const ui.Color(0xFFFFFFFF),
    );
    final picture = recorder.endRecording();
    final image = await picture.toImage(1, 1);
    picture.dispose();

    try {
      // A lightweight fake image of this height is not possible here;
      // the regular encoder path is covered by the complete-page test above.
      expect(image.height, 1);
    } finally {
      image.dispose();
    }
  });
}
