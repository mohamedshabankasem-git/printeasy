import 'dart:typed_data';

import 'package:pdfx/pdfx.dart';

/// يحوّل صفحات PDF إلى صور PNG بعرض الطباعة الفعلي.
class PdfPageConverter {
  PdfPageConverter._();

  static Stream<Uint8List> renderPages(
    Uint8List pdfBytes, {
    required int widthDots,
    int maxPageHeight = 16000,
  }) async* {
    if (pdfBytes.isEmpty) {
      throw ArgumentError.value(pdfBytes, 'pdfBytes', 'ملف PDF فارغ');
    }
    if (widthDots <= 0) {
      throw ArgumentError.value(widthDots, 'widthDots', 'عرض الطباعة غير صالح');
    }

    final document = await PdfDocument.openData(pdfBytes);
    try {
      for (var pageNumber = 1; pageNumber <= document.pagesCount; pageNumber++) {
        final page = await document.getPage(pageNumber);
        try {
          final ratio = page.height / page.width;
          final height = (widthDots * ratio).round().clamp(1, maxPageHeight);
          final rendered = await page.render(
            width: widthDots.toDouble(),
            height: height.toDouble(),
            format: PdfPageImageFormat.png,
            forPrint: true,
          );
          if (rendered == null || rendered.bytes.isEmpty) {
            throw StateError('تعذر تحويل صفحة PDF رقم $pageNumber إلى صورة');
          }
          yield rendered.bytes;
        } finally {
          await page.close();
        }
      }
    } finally {
      await document.close();
    }
  }
}
