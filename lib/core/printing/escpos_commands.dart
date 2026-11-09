import 'dart:convert';
import 'dart:typed_data';

/// محاذاة الطباعة. الترتيب مطابق لقيم ESC a (0=يسار، 1=وسط، 2=يمين)
enum PrintAlign { left, center, right }

/// باني أوامر ESC/POS. كل دالة تُرجع الكائن نفسه للتسلسل (chaining).
class EscPos {
  static const int esc = 0x1B;
  static const int gs = 0x1D;
  static const int lf = 0x0A;

  final BytesBuilder _b = BytesBuilder();

  Uint8List build() => _b.toBytes();

  /// تهيئة الطابعة (ESC @)
  EscPos initialize() {
    _b.add([esc, 0x40]);
    return this;
  }

  /// محاذاة (ESC a n)
  EscPos align(PrintAlign a) {
    _b.add([esc, 0x61, a.index]);
    return this;
  }

  /// خط عريض (ESC E n)
  EscPos bold(bool on) {
    _b.add([esc, 0x45, on ? 1 : 0]);
    return this;
  }

  /// تسطير (ESC - n) 0=بدون، 1=رفيع، 2=سميك
  EscPos underline(int mode) {
    _b.add([esc, 0x2D, mode.clamp(0, 2)]);
    return this;
  }

  /// حجم الخط (GS ! n) العرض والارتفاع من 1 إلى 8
  EscPos textSize(int width, int height) {
    final w = (width.clamp(1, 8) - 1) << 4;
    final h = height.clamp(1, 8) - 1;
    _b.add([gs, 0x21, w | h]);
    return this;
  }

  /// نص ASCII/Latin فقط (الحروف العربية تُطبع كصورة عبر ReceiptRenderer)
  EscPos text(String s, {bool newLine = true}) {
    final safe = s.runes.map((r) => r < 128 ? r : 0x3F).toList(); // ? للأحرف غير المدعومة
    _b.add(latin1.encode(String.fromCharCodes(safe)));
    if (newLine) _b.addByte(lf);
    return this;
  }

  EscPos newLine([int n = 1]) {
    for (var i = 0; i < n; i++) {
      _b.addByte(lf);
    }
    return this;
  }

  /// تغذية الورق بالنقاط (ESC J n) — 8 نقاط = 1 مم تقريباً (طابعات 203dpi)
  EscPos feedDots(int dots) {
    var left = dots;
    while (left > 0) {
      final n = left > 255 ? 255 : left;
      _b.add([esc, 0x4A, n]);
      left -= n;
    }
    return this;
  }

  /// تغذية الورق بالأسطر (ESC d n)
  EscPos feedLines(int n) {
    _b.add([esc, 0x64, n.clamp(0, 255)]);
    return this;
  }

  /// قطع الورق (GS V). partial=true قطع جزئي
  EscPos cut({bool partial = true}) {
    _b.add([gs, 0x56, partial ? 66 : 65, 0x00]);
    return this;
  }

  /// طباعة صورة Raster جاهزة (GS v 0)
  EscPos rasterChunk(Uint8List packed, int widthBytes, int rows) {
    _b.add([gs, 0x76, 0x30, 0x00, widthBytes & 0xFF, widthBytes >> 8, rows & 0xFF, rows >> 8]);
    _b.add(packed);
    return this;
  }

  /// QR أصلي عبر الطابعة (GS ( k) — بديل أسرع عند دعم الطابعة
  EscPos qrNative(String data, {int moduleSize = 6, int ecc = 49}) {
    final bytes = utf8.encode(data);
    _b.add([gs, 0x28, 0x6B, 0x04, 0x00, 0x31, 0x41, 0x32, 0x00]); // model 2
    _b.add([gs, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x43, moduleSize.clamp(1, 16)]);
    _b.add([gs, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x45, ecc]); // 48..51
    final len = bytes.length + 3;
    _b.add([gs, 0x28, 0x6B, len & 0xFF, len >> 8, 0x31, 0x50, 0x30]);
    _b.add(bytes);
    _b.add([gs, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x51, 0x30]);
    return this;
  }

  /// باركود Code128 أصلي (GS k 73)
  EscPos barcodeNative(String data, {int height = 80, int width = 2}) {
    final payload = latin1.encode('{B$data');
    _b.add([gs, 0x68, height.clamp(1, 255)]); // الارتفاع
    _b.add([gs, 0x77, width.clamp(2, 6)]); // العرض
    _b.add([gs, 0x48, 0x02]); // النص أسفل الباركود
    _b.add([gs, 0x6B, 73, payload.length]);
    _b.add(payload);
    return this;
  }
}
