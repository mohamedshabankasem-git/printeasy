import 'dart:convert';
import 'dart:typed_data';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart';

class BatchTable {
  const BatchTable(this.headers, this.rows);
  final List<String> headers;
  final List<List<String>> rows;
}

/// قراءة ملفات CSV و XLSX: الصف الأول = أسماء الأعمدة
class BatchFileParser {
  static BatchTable parse(String fileName, Uint8List bytes) {
    final ext = fileName.toLowerCase().split('.').last;
    final raw = ext == 'xlsx' ? _excel(bytes) : _csv(bytes);
    if (raw.isEmpty) throw Exception('الملف فارغ');

    final headers = raw.first.map((e) => e.trim()).toList();
    final rows = raw
        .skip(1)
        .where((r) => r.any((c) => c.trim().isNotEmpty))
        .map((r) => List<String>.generate(headers.length, (i) => i < r.length ? r[i].trim() : ''))
        .toList();
    if (rows.isEmpty) throw Exception('لا توجد صفوف بيانات بعد صف العناوين');
    return BatchTable(headers, rows);
  }

  static List<List<String>> _csv(Uint8List bytes) {
    var text = utf8.decode(bytes, allowMalformed: true);
    if (text.startsWith('\uFEFF')) text = text.substring(1); // إزالة BOM
    text = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final first = text.split('\n').first;
    final delimiter = ';'.allMatches(first).length > ','.allMatches(first).length ? ';' : ',';
    final rows = CsvToListConverter(
      fieldDelimiter: delimiter,
      eol: '\n',
      shouldParseNumbers: false,
    ).convert(text);
    return rows.map((r) => r.map((c) => c.toString()).toList()).toList();
  }

  static List<List<String>> _excel(Uint8List bytes) {
    final book = Excel.decodeBytes(bytes);
    for (final sheet in book.tables.values) {
      if (sheet.maxRows > 0) {
        return sheet.rows.map((row) => row.map((c) => _cellText(c?.value)).toList()).toList();
      }
    }
    return [];
  }

  /// استخراج نص الخلية بغض النظر عن نوعها (نص/رقم/تاريخ)
  static String _cellText(Object? v) {
    if (v == null) return '';
    try {
      final dynamic val = (v as dynamic).value;
      if (val == null) return '';
      if (val is String) return val;
      if (val is double && val == val.roundToDouble()) return val.toStringAsFixed(0);
      if (val is num || val is bool) return val.toString();
      return _spanText(val); // TextSpan الخاص بمكتبة excel
    } catch (_) {
      return v.toString();
    }
  }

  static String _spanText(dynamic span) {
    final text = (span.text as String?) ?? '';
    final children = span.children as List?;
    return text + (children?.map(_spanText).join() ?? '');
  }
}
