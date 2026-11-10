import 'dart:typed_data';
import 'dart:ui' as ui;

import 'escpos_commands.dart';

/// Converts a complete page image into one monochrome ESC/POS raster command.
/// The Bluetooth transport may split the byte stream into protocol packets,
/// but the printer receives a single GS v 0 image command for the whole page.
class RasterEncoder {
  static Future<Uint8List> encode(
    ui.Image image, {
    int threshold = 128,
  }) async {
    if (image.width <= 0 || image.height <= 0) {
      throw ArgumentError('أبعاد الصورة يجب أن تكون أكبر من صفر');
    }
    // GS v 0 stores raster height in an unsigned 16-bit field.
    if (image.height > 65535) {
      throw ArgumentError.value(
        image.height,
        'image.height',
        'ارتفاع الصفحة يتجاوز الحد المدعوم لأمر Raster واحد',
      );
    }

    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (byteData == null) throw StateError('تعذر قراءة بيانات الصورة');

    final pixels = byteData.buffer.asUint8List();
    final width = image.width;
    final height = image.height;
    final widthBytes = (width + 7) ~/ 8;
    final packed = Uint8List(widthBytes * height);

    for (var y = 0; y < height; y++) {
      final rowStart = y * width * 4;
      for (var x = 0; x < width; x++) {
        final i = rowStart + x * 4;
        if (pixels[i + 3] < 128) continue; // Transparent pixels print white.
        final luminance =
            0.299 * pixels[i] + 0.587 * pixels[i + 1] + 0.114 * pixels[i + 2];
        if (luminance < threshold) {
          packed[y * widthBytes + (x >> 3)] |= 0x80 >> (x & 7);
        }
      }
    }

    return EscPos().rasterChunk(packed, widthBytes, height).build();
  }
}
