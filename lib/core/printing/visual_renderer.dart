import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/painting.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'escpos_commands.dart';
import 'receipt_renderer.dart';
import 'visual_layout.dart';

/// يحوّل القالب المرئي (JSON) إلى صورة واحدة بعرض الورق لتُطبع كـ Raster
class VisualRenderer {
  VisualRenderer({required this.widthDots, this.fontFamily});

  final int widthDots;
  final String? fontFamily;

  static const double _baseFont = 24;

  Future<ui.Image> render(VisualLayout layout) async {
    final draws = <void Function(Canvas)>[];
    var bottom = layout.height;
    const black = Color(0xFF000000);

    for (final e in layout.elements) {
      switch (e.type) {
        case VisualType.text:
          if (e.text.isEmpty) break;
          final arabic = ReceiptRenderer.isArabic(e.text);
          final tp = TextPainter(
            text: TextSpan(
              text: e.text,
              style: TextStyle(
                color: black,
                fontSize: _baseFont * e.size.clamp(1, 4),
                fontWeight: e.bold ? FontWeight.w900 : FontWeight.w600,
                fontFamily: fontFamily,
                height: 1.25,
              ),
            ),
            textDirection: arabic ? TextDirection.rtl : TextDirection.ltr,
            textAlign: switch (e.align) {
              PrintAlign.left => TextAlign.left,
              PrintAlign.center => TextAlign.center,
              PrintAlign.right => TextAlign.right,
            },
          )..layout(minWidth: e.w, maxWidth: e.w);
          bottom = math.max(bottom, e.y + tp.height);
          draws.add((c) => tp.paint(c, Offset(e.x, e.y)));

        case VisualType.qr:
          if (e.text.trim().isEmpty) break;
          final side = math.min(e.w, e.h);
          try {
            final painter = QrPainter(
              data: e.text,
              version: QrVersions.auto,
              errorCorrectionLevel: QrErrorCorrectLevel.M,
              gapless: true,
              eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: black),
              dataModuleStyle: const QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.square,
                color: black,
              ),
            );
            draws.add((c) {
              c.save();
              c.translate(e.x + (e.w - side) / 2, e.y + (e.h - side) / 2);
              painter.paint(c, Size(side, side));
              c.restore();
            });
          } catch (_) {}

        case VisualType.image:
          if (e.imageB64 == null) break;
          try {
            final codec = await ui.instantiateImageCodec(base64Decode(e.imageB64!));
            final img = (await codec.getNextFrame()).image;
            final scale = math.min(e.w / img.width, e.h / img.height);
            final dw = img.width * scale;
            final dh = img.height * scale;
            final dst = Rect.fromLTWH(e.x + (e.w - dw) / 2, e.y + (e.h - dh) / 2, dw, dh);
            draws.add((c) => c.drawImageRect(
                  img,
                  Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
                  dst,
                  Paint()..filterQuality = FilterQuality.medium,
                ));
          } catch (_) {}

        case VisualType.line:
          draws.add((c) => c.drawRect(
                Rect.fromLTWH(e.x, e.y + e.h / 2 - 1, e.w, 2),
                Paint()..color = black,
              ));
      }
    }

    final h = math.max(bottom.ceil(), 8);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, widthDots.toDouble(), h.toDouble()),
      Paint()..color = const Color(0xFFFFFFFF),
    );
    for (final d in draws) {
      d(canvas);
    }
    return recorder.endRecording().toImage(widthDots, h);
  }
}
