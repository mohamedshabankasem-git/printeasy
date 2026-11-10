import 'dart:convert';
import 'dart:typed_data';

import 'package:csv/csv.dart';
import 'package:excel/excel.dart';

import 'text_page_renderer.dart';

/// يحوّل ملفات CSV وXLSX والنصوص وHTML إلى صفحات صور حرارية.
/// يعرض كل ورقة Excel مستقلة، ويقسّم الأوراق الطويلة إلى صفحات متتابعة.
class TabularFileConverter {
  TabularFileConverter._();

  static Future<List<Uint8List>> convert({
    required String fileName,
    required Uint8List bytes,
    required int widthDots,
  }) async {
    if (bytes.isEmpty) throw ArgumentError('الملف فارغ');
    final ext = fileName.toLowerCase().split('.').last;
    if (ext == 'xlsx') {
      final workbook = Excel.decodeBytes(bytes);
      if (workbook.tables.isEmpty) throw FormatException('لا توجد أوراق في ملف Excel');
      for (final entry in workbook.tables.entries) {
        final lines = <String>['ورقة: ${entry.key}', ''];
        for (final row in entry.value.rows) {
          final values = row.map((cell) => _cellText(cell?.value)).toList();
          if (values.every((value) => value.trim().isEmpty)) continue;
          lines.add(values.join('  |  '));
        }
        pages.addAll(await TextPageRenderer.render(
          lines,
          widthDots: widthDots,
        ));
      }
      return pages;
    }

    if (ext == 'csv') {
      final text = utf8.decode(bytes, allowMalformed: true);
      final rows = const CsvToListConverter(shouldParseNumbers: false).convert(text);
      final lines = rows.map((row) => row.map((cell) => cell?.toString() ?? '').join('  |  ')).toList();
      return TextPageRenderer.render(lines, widthDots: widthDots);
    }

    if (ext == 'txt' || ext == 'log' || ext == 'html' || ext == 'htm') {
      var text = utf8.decode(bytes, allowMalformed: true);
      if (ext == 'html' || ext == 'htm') {
        text = _htmlToText(text);
      }
      return TextPageRenderer.render(
        text.replaceAll('\r\n', '\n').replaceAll('\r', '\n').split('\n'),
        widthDots: widthDots,
      );
    }

    throw FormatException('صيغة غير مدعومة في محول الجداول: .$ext');
  }

  static String _cellText(CellValue? value) {
    if (value == null) return '';
    return switch (value) {
      TextCellValue() => value.value.toString(),
      FormulaCellValue() => value.formula,
      IntCellValue() => value.value.toString(),
      DoubleCellValue() => value.value.toString(),
      BoolCellValue() => value.value ? 'نعم' : 'لا',
      DateCellValue() => value.asDateTimeLocal().toString().split(' ').first,
      TimeCellValue() => value.asDuration().toString(),
      DateTimeCellValue() => value.asDateTimeLocal().toString(),
    };
  }

  static String _htmlToText(String html) {
    var text = html
        .replaceAll(RegExp(r'<(script|style)[^>]*>[\s\S]*?</\1>', caseSensitive: false), '')
        .replaceAll(RegExp(r'<br\s*/?>|</(p|div|tr|h[1-6]|li|table)>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<[^>]+>'), ' ');
    const entities = <String, String>{
      '&nbsp;': ' ',
      '&amp;': '&',
      '&lt;': '<',
      '&gt;': '>',
      '&quot;': '"',
      '&#39;': "'",
      '&apos;': "'",
    };
    entities.forEach((key, value) => text = text.replaceAll(key, value));
    return text
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .replaceAll(RegExp(r'\n\s*\n+'), '\n')
        .trim();
  }
}
