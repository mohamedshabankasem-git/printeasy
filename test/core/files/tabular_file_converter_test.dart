import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:printeasy/core/files/tabular_file_converter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('converts CSV rows to printable PNG pages', () async {
    final bytes = Uint8List.fromList(utf8.encode('Name,Price\nقلم,12\nدفتر,25'));
    final pages = await TabularFileConverter.convert(
      fileName: 'items.csv',
      bytes: bytes,
      widthDots: 384,
    );

    expect(pages, isNotEmpty);
    expect(pages.first.sublist(0, 4), [137, 80, 78, 71]);
  });

  test('converts plain text content to printable pages', () async {
    final bytes = Uint8List.fromList(utf8.encode('مرحبا\nPrintEasy'));
    final pages = await TabularFileConverter.convert(
      fileName: 'note.txt',
      bytes: bytes,
      widthDots: 576,
    );

    expect(pages, isNotEmpty);
    expect(pages.first.sublist(0, 4), [137, 80, 78, 71]);
  });
}
