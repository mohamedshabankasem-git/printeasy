import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import 'text_page_renderer.dart';

/// استخراج نص المستندات الحديثة DOCX وPPTX من حاوية Office Open XML.
/// يحافظ على ترتيب الفقرات والشرائح، ثم يرسم النص إلى صور للطابعة.
class OfficeOpenXmlConverter {
  OfficeOpenXmlConverter._();

  static Future<List<Uint8List>> convert({
    required String fileName,
    required Uint8List bytes,
    required int widthDots,
  }) async {
    if (bytes.isEmpty) throw ArgumentError('الملف فارغ');
    final ext = fileName.toLowerCase().split('.').last;
    final archive = ZipDecoder().decodeBytes(bytes);
    final lines = <String>[];

    if (ext == 'docx') {
      final documents = archive.files.where((f) => f.isFile && f.name == 'word/document.xml').toList();
      if (documents.isEmpty) throw FormatException('ملف Word لا يحتوي على المستند الرئيسي');
      final xml = utf8.decode(documents.first.content as List<int>, allowMalformed: true);
      for (final paragraph in RegExp(r'<w:p(?:\s[^>]*)?>([\s\S]*?)</w:p>').allMatches(xml)) {
        final text = _extractRuns(paragraph.group(1) ?? '', 'w:t');
        if (text.trim().isNotEmpty) lines.add(text);
      }
      if (lines.isEmpty) throw FormatException('لم يتم العثور على نص داخل ملف Word');
      return TextPageRenderer.render(lines, widthDots: widthDots);
    }

    if (ext == 'pptx') {
      final slides = archive.files
          .where((f) => f.isFile && RegExp(r'^ppt/slides/slide\d+\.xml$').hasMatch(f.name))
          .toList()
        ..sort((a, b) => _slideNumber(a.name).compareTo(_slideNumber(b.name)));
      if (slides.isEmpty) throw FormatException('لم يتم العثور على شرائح داخل PowerPoint');
      for (var i = 0; i < slides.length; i++) {
        final xml = utf8.decode(slides[i].content as List<int>, allowMalformed: true);
        lines.add('الشريحة ${i + 1}');
        for (final paragraph in RegExp(r'<a:p(?:\s[^>]*)?>([\s\S]*?)</a:p>').allMatches(xml)) {
          final text = _extractRuns(paragraph.group(1) ?? '', 'a:t');
          if (text.trim().isNotEmpty) lines.add(text);
        }
        lines.add('');
      }
      return TextPageRenderer.render(lines, widthDots: widthDots);
    }

    throw FormatException('صيغة Office غير مدعومة: .$ext');
  }

  static int _slideNumber(String name) =>
      int.tryParse(RegExp(r'slide(\d+)\.xml$').firstMatch(name)?.group(1) ?? '') ?? 0;

  static String _extractRuns(String fragment, String tag) {
    final withTabs = fragment.replaceAll(RegExp(r'<(?:w:tab|a:tab)[^>]*/>'), '    ');
    final parts = RegExp('<$tag(?:\\s[^>]*)?>([\\s\\S]*?)</$tag>')
        .allMatches(withTabs)
        .map((match) => _decodeXml(match.group(1) ?? ''));
    return parts.join();
  }

  static String _decodeXml(String value) {
    return value
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'")
        .replaceAllMapped(RegExp(r'&#(\d+);'), (m) => String.fromCharCode(int.parse(m.group(1)!)))
        .replaceAllMapped(RegExp(r'&#x([0-9a-fA-F]+);'), (m) => String.fromCharCode(int.parse(m.group(1)!, radix: 16)));
  }
}
