import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'escpos_commands.dart';

/// تحويل صورة ui.Image إلى أوامر Raster أحادية اللون (1-bit)
class RasterEncoder {
  /// threshold: كلما زاد أصبحت الطباعة أغمق
  /// chunkRows: عدد الصفوف في كل أمر؛ القيمة الصغيرة تقلل حجم مخزن الأمر
  static Future<Uint8List> encode(
    ui.Image image, {
    int threshold = 128,
    int chunkRows = 24,
  }) async {
    if (chunkRows <= 0) {
      throw ArgumentError.value(chunkRows, 'chunkRows', 'يجب أن يكون أكبر من صفر');
    }
    final bd = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (bd == null) throw StateError('تعذر قراءة بيانات الصورة');
    final px = bd.buffer.asUint8List();
    final w = image.width;
    final h = image.height;
    final widthBytes = (w + 7) ~/ 8;
    final out = EscPos();

    for (var y0 = 0; y0 < h; y0 += chunkRows) {
      final rows = math.min(chunkRows, h - y0);
      final data = Uint8List(widthBytes * rows);
      for (var r = 0; r < rows; r++) {
        final rowStart = (y0 + r) * w * 4;
        for (var x = 0; x < w; x++) {
          final i = rowStart + x * 4;
          final a = px[i + 3];
          if (a < 128) continue; // شفاف = أبيض
          final lum = 0.299 * px[i] + 0.587 * px[i + 1] + 0.114 * px[i + 2];
          if (lum < threshold) {
            data[r * widthBytes + (x >> 3)] |= (0x80 >> (x & 7));
          }
        }
      }
      out.rasterChunk(data, widthBytes, rows);
    }
    return out.build();
  }
}
