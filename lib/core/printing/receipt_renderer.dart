import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:barcode/barcode.dart';
import 'package:flutter/painting.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'escpos_commands.dart';
import 'print_block.dart';

/// يرسم عناصر الإيصال كلها على صورة واحدة بعرض الورق (بالنقاط).
/// هذا هو سر دعم العربية: Flutter يشكّل الحروف ويرتبها يمين←يسار،
/// ثم تُرسل الصورة للطابعة كـ Raster فلا تعتمد على خطوط الطابعة.
class ReceiptRenderer {
  ReceiptRenderer({required this.widthDots, this.fontFamily});

  final int widthDots;
  final String? fontFamily;

  static const double _baseFont = 26;
  static final RegExp _arabic = RegExp(r'[\u0600-\u06FF\u0750-\u077F\uFB50-\uFDFF\uFE70-\uFEFF]');

  static bool isArabic(String s) => _arabic.hasMatch(s);

  Future<ui.Image> render(List<PrintBlock> blocks) async {
    final items = <_Item>[];
    for (final b in blocks) {
      final item = await _build(b);
      if (item != null) items.add(item);
    }
    final total = items.fold<double>(0, (s, i) => s + i.height);
    final height = math.max(total.ceil(), 8);

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, widthDots.toDouble(), height.toDouble()),
      Paint()..color = const Color(0xFFFFFFFF),
    );
    var y = 0.0;
    for (final i in items) {
      i.paint(canvas, y);
      y += i.height;
    }
    return recorder.endRecording().toImage(widthDots, height);
  }

  TextStyle _style(bool bold, int size) => TextStyle(
        color: const Color(0xFF000000),
        fontSize: _baseFont * size.clamp(1, 4),
        fontWeight: bold ? FontWeight.w900 : FontWeight.w600,
        fontFamily: fontFamily,
        height: 1.25,
      );

  TextAlign _textAlign(PrintAlign a) => switch (a) {
        PrintAlign.left => TextAlign.left,
        PrintAlign.center => TextAlign.center,
        PrintAlign.right => TextAlign.right,
      };

  double _xFor(PrintAlign a, double w) => switch (a) {
        PrintAlign.left => 0,
        PrintAlign.center => (widthDots - w) / 2,
        PrintAlign.right => widthDots - w,
      };

  Future<_Item?> _build(PrintBlock b) async {
    switch (b) {
      case TextBlock():
        if (b.text.trim().isEmpty) {
          return _Item(_baseFont * b.size, (c, y) {});
        }
        final arabic = isArabic(b.text);
        final align = b.align ?? (arabic ? PrintAlign.right : PrintAlign.left);
        final tp = TextPainter(
          text: TextSpan(text: b.text, style: _style(b.bold, b.size)),
          textDirection: arabic ? TextDirection.rtl : TextDirection.ltr,
          textAlign: _textAlign(align),
        )..layout(minWidth: widthDots.toDouble(), maxWidth: widthDots.toDouble());
        return _Item(tp.height, (c, y) => tp.paint(c, Offset(0, y)));

      case RowBlock():
        final rtl = isArabic(b.first) || isArabic(b.second);
        final style = _style(b.bold, b.size);
        final dir = rtl ? TextDirection.rtl : TextDirection.ltr;
        final tp1 = TextPainter(
          text: TextSpan(text: b.first, style: style),
          textDirection: dir,
        )..layout(maxWidth: widthDots * 0.68);
        final tp2 = TextPainter(
          text: TextSpan(text: b.second, style: style),
          textDirection: TextDirection.ltr, // الأرقام والمبالغ تبقى LTR
        )..layout(maxWidth: widthDots * 0.32);
        final h = math.max(tp1.height, tp2.height);
        return _Item(h, (c, y) {
          final x1 = rtl ? widthDots - tp1.width : 0.0;
          final x2 = rtl ? 0.0 : widthDots - tp2.width;
          tp1.paint(c, Offset(x1, y));
          tp2.paint(c, Offset(x2, y));
        });

      case SeparatorBlock():
        return _Item(14, (c, y) {
          final p = Paint()
            ..color = const Color(0xFF000000)
            ..strokeWidth = 2;
          for (double x = 0; x < widthDots; x += 10) {
            c.drawLine(Offset(x, y + 7), Offset(math.min(x + 6, widthDots.toDouble()), y + 7), p);
          }
        });

      case QrBlock():
        final size = math.min(b.sizeDots, widthDots).toDouble();
        try {
          final painter = QrPainter(
            data: b.data,
            version: QrVersions.auto,
            errorCorrectionLevel: QrErrorCorrectLevel.M,
            gapless: true,
            eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Color(0xFF000000)),
            dataModuleStyle: const QrDataModuleStyle(
              dataModuleShape: QrDataModuleShape.square,
              color: Color(0xFF000000),
            ),
          );
          return _Item(size + 12, (c, y) {
            c.save();
            c.translate(_xFor(b.align, size), y + 6);
            painter.paint(c, Size(size, size));
            c.restore();
          });
        } catch (_) {
          return _textItem('[QR]');
        }

      case BarcodeBlock():
        try {
          final w = widthDots * 0.9;
          final h = b.heightDots.toDouble();
          final elements = Barcode.code128().make(b.data, width: w, height: h, drawText: false);
          return _Item(h + 12, (c, y) {
            final p = Paint()..color = const Color(0xFF000000);
            final dx = _xFor(b.align, w);
            for (final e in elements) {
              if (e is BarcodeBar && e.black) {
                c.drawRect(Rect.fromLTWH(dx + e.left, y + 6 + e.top, e.width, e.height), p);
              }
            }
          });
        } catch (_) {
          // Code128 لا يدعم العربية؛ نطبع النص بدل الباركود
          return _textItem(b.data);
        }

      case ImageBlock():
        final codec = await ui.instantiateImageCodec(b.bytes, targetWidth: widthDots);
        final frame = await codec.getNextFrame();
        final img = frame.image;
        final scale = img.width > widthDots ? widthDots / img.width : 1.0;
        final w = img.width * scale;
        final h = img.height * scale;
        return _Item(h + 8, (c, y) {
          final dst = Rect.fromLTWH(_xFor(b.align, w), y + 4, w, h);
          c.drawImageRect(
            img,
            Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
            dst,
            Paint()..filterQuality = FilterQuality.medium,
          );
        });

      case FeedBlock():
        return _Item(b.dots.toDouble(), (c, y) {});

      case CutBlock():
        return null; // يعالجه PrintService
    }
  }

  _Item _textItem(String t) {
    final tp = TextPainter(
      text: TextSpan(text: t, style: _style(false, 1)),
      textDirection: isArabic(t) ? TextDirection.rtl : TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout(minWidth: widthDots.toDouble(), maxWidth: widthDots.toDouble());
    return _Item(tp.height, (c, y) => tp.paint(c, Offset(0, y)));
  }
}

class _Item {
  _Item(this.height, this.paint);
  final double height;
  final void Function(Canvas canvas, double y) paint;
}
