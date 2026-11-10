import 'dart:typed_data';
import 'dart:ui' as ui;

/// يرسم صفحات نصية إلى صور حرارية بعرض محدد، مع دعم اتجاه العربية والتفاف السطور.
class TextPageRenderer {
  TextPageRenderer._();

  static Future<List<Uint8List>> render(
    List<String> lines, {
    required int widthDots,
    int maxHeight = 1400,
    double fontSize = 20,
    double horizontalPadding = 8,
  }) async {
    if (widthDots < 64) throw ArgumentError.value(widthDots, 'widthDots');
    if (maxHeight < 32) throw ArgumentError.value(maxHeight, 'maxHeight');
    if (!fontSize.isFinite || fontSize <= 0) {
      throw ArgumentError.value(fontSize, 'fontSize');
    }
    if (!horizontalPadding.isFinite || horizontalPadding < 0 ||
        horizontalPadding * 2 >= widthDots) {
      throw ArgumentError.value(horizontalPadding, 'horizontalPadding');
    }
    final contentWidth = widthDots - horizontalPadding * 2;
    // كل سطر يلف تلقائياً عند عرض الورق، وتُحفظ فواصل الأسطر.
    final chunks = <String>[];
    for (final line in lines) {
      chunks.add(line.isEmpty ? ' ' : line);
    }

    final pages = <Uint8List>[];
    var current = <ui.Paragraph>[];
    var currentHeight = 12.0;

    Future<void> flush() async {
      if (current.isEmpty) return;
      final height = currentHeight.ceil() + 12;
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      canvas.drawColor(const ui.Color(0xFFFFFFFF), ui.BlendMode.src);
      var y = 6.0;
      for (final paragraph in current) {
        canvas.drawParagraph(paragraph, ui.Offset(horizontalPadding, y));
        y += paragraph.height + 5;
      }
      final picture = recorder.endRecording();
      final image = await picture.toImage(widthDots, height);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) throw StateError('تعذر إنشاء صورة الصفحة');
      pages.add(data.buffer.asUint8List());
      image.dispose();
      picture.dispose();
      current = <ui.Paragraph>[];
      currentHeight = 12;
    }

    for (final line in chunks) {
      final paragraphBuilder = ui.ParagraphBuilder(
        ui.ParagraphStyle(
          textDirection: ui.TextDirection.rtl,
          textAlign: ui.TextAlign.right,
          fontSize: fontSize,
          height: 1.25,
        ),
      )..pushStyle(ui.TextStyle(
          color: const ui.Color(0xFF000000),
          fontSize: fontSize,
          fontWeight: ui.FontWeight.normal,
        ));
      paragraphBuilder.addText(line);
      final paragraph = paragraphBuilder.build()
        ..layout(ui.ParagraphConstraints(width: contentWidth));
      if (current.isNotEmpty && currentHeight + paragraph.height + 5 > maxHeight) {
        await flush();
      }
      current.add(paragraph);
      currentHeight += paragraph.height + 5;
    }
    await flush();
    return pages;
  }
}
