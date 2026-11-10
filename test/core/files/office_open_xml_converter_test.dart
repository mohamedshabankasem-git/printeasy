import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:printeasy/core/files/office_open_xml_converter.dart';

Uint8List _zip(Map<String, String> entries) {
  final archive = Archive();
  for (final entry in entries.entries) {
    final bytes = utf8.encode(entry.value);
    archive.addFile(ArchiveFile(entry.key, bytes.length, bytes));
  }
  return Uint8List.fromList(ZipEncoder().encode(archive)!);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('extracts ordered Word paragraphs and renders PNG pages', () async {
    final bytes = _zip({
      'word/document.xml':
          '<w:document><w:body><w:p><w:r><w:t>فاتورة تجريبية</w:t></w:r></w:p>'
          '<w:p><w:r><w:t>المجموع 125</w:t></w:r></w:p></w:body></w:document>',
    });

    final pages = await OfficeOpenXmlConverter.convert(
      fileName: 'sample.docx',
      bytes: bytes,
      widthDots: 384,
    );

    expect(pages, isNotEmpty);
    expect(pages.first.sublist(0, 4), [137, 80, 78, 71]);
  });

  test('extracts PowerPoint slides in numeric order', () async {
    final bytes = _zip({
      'ppt/slides/slide2.xml':
          '<p:sld><a:p><a:r><a:t>الشريحة الثانية</a:t></a:r></a:p></p:sld>',
      'ppt/slides/slide1.xml':
          '<p:sld><a:p><a:r><a:t>الشريحة الأولى</a:t></a:r></a:p></p:sld>',
    });

    final pages = await OfficeOpenXmlConverter.convert(
      fileName: 'sample.pptx',
      bytes: bytes,
      widthDots: 576,
    );

    expect(pages, isNotEmpty);
    expect(pages.first.sublist(0, 4), [137, 80, 78, 71]);
  });

  test('rejects an Office archive without the main document', () async {
    final bytes = _zip({'word/styles.xml': '<w:styles/>'});

    expect(
      OfficeOpenXmlConverter.convert(
        fileName: 'broken.docx',
        bytes: bytes,
        widthDots: 384,
      ),
      throwsFormatException,
    );
  });
}
