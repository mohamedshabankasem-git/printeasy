import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/printing/print_block.dart';
import '../../../core/files/pdf_page_converter.dart';
import '../../../core/files/tabular_file_converter.dart';
import '../../../core/files/office_open_xml_converter.dart';
import '../../connection/presentation/connection_controller.dart';
import '../../printing/data/print_job_runner.dart';
import '../../settings/presentation/settings_providers.dart';
import 'share_listener.dart';

/// شاشة معاينة وطباعة جميع العناصر المستلمة من تطبيق آخر.
class ShareScreen extends ConsumerStatefulWidget {
  const ShareScreen({super.key, required this.payload});
  final SharedPayload payload;

  @override
  ConsumerState<ShareScreen> createState() => _ShareScreenState();
}

class _ShareScreenState extends ConsumerState<ShareScreen> {
  bool _printing = false;
  String? _result;
  bool _ok = false;
  late final List<SharedItem> _items;

  @override
  void initState() {
    super.initState();
    _items = List<SharedItem>.of(widget.payload.items);
    Future.microtask(() async {
      final auto = ref.read(settingsProvider).shareAutoPrint;
      final connected = ref.read(connectionControllerProvider).isConnected;
      if (auto && connected) await _print();
    });
  }

  Future<void> _addFiles() async {
    if (_printing) return;
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowMultiple: true,
      withData: true,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png', 'webp', 'csv', 'xlsx', 'txt', 'html', 'htm', 'docx', 'pptx'],
    );
    if (result == null || result.files.isEmpty) return;
    final added = <SharedItem>[];
    for (final file in result.files) {
      try {
        final bytes = file.bytes ?? (file.path == null ? null : await File(file.path!).readAsBytes());
        if (bytes == null || bytes.isEmpty) continue;
        final ext = file.extension?.toLowerCase() ?? '';
        final kind = const ['jpg', 'jpeg', 'png', 'webp'].contains(ext) ? 'image' : 'file';
        added.add(SharedItem(name: file.name, kind: kind, bytes: bytes));
      } catch (_) {
        added.add(SharedItem(name: file.name, kind: 'other'));
      }
    }
    if (!mounted || added.isEmpty) return;
    setState(() {
      _items.addAll(added);
      _result = 'تمت إضافة ${added.length} ملف';
      _ok = false;
    });
  }

  String _short(String t) {
    final one = t.replaceAll('\n', ' ').trim();
    return one.length > 30 ? '${one.substring(0, 30)}…' : one;
  }

  Future<void> _print() async {
    if (_printing) return;
    setState(() {
      _printing = true;
      _result = null;
    });

    final blocks = <PrintBlock>[];
    final unsupported = <String>[];
    final widthDots = ref.read(settingsProvider).toPrintSettings().widthDots;
    try {
      for (final item in _items) {
        if (item.isImage && item.bytes != null) {
          blocks.add(ImageBlock(item.bytes!));
          blocks.add(const FeedBlock(12));
        } else if (item.kind == 'text' && item.text != null) {
          for (final line in item.text!.split('\n')) {
            blocks.add(TextBlock(line));
          }
          blocks.add(const FeedBlock(12));
        } else if (item.kind == 'file' &&
            item.bytes != null &&
            item.name.toLowerCase().endsWith('.pdf')) {
          await for (final page in PdfPageConverter.renderPages(
            item.bytes!,
            widthDots: widthDots,
          )) {
            blocks.add(ImageBlock(page));
            blocks.add(const FeedBlock(12));
          }
        } else if (item.kind == 'file' && item.bytes != null &&
            const ['csv', 'xlsx', 'txt', 'html', 'htm'].contains(item.name.toLowerCase().split('.').last)) {
          final pages = await TabularFileConverter.convert(
            fileName: item.name,
            bytes: item.bytes!,
            widthDots: widthDots,
          );
          for (final page in pages) {
            blocks.add(ImageBlock(page));
            blocks.add(const FeedBlock(12));
          }
        } else if (item.kind == 'file' && item.bytes != null &&
            const ['docx', 'pptx'].contains(item.name.toLowerCase().split('.').last)) {
          final pages = await OfficeOpenXmlConverter.convert(
            fileName: item.name,
            bytes: item.bytes!,
            widthDots: widthDots,
          );
          for (final page in pages) {
            blocks.add(ImageBlock(page));
            blocks.add(const FeedBlock(12));
          }
        } else {
          unsupported.add(item.name);
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _printing = false;
        _ok = false;
        _result = 'تعذر تجهيز الملف للطباعة: ${e.toString().replaceFirst('Exception: ', '')}';
      });
      return;
    }

    final PrintResult r;
    if (blocks.isEmpty) {
      r = PrintResult.fail('لا توجد ملفات مدعومة للطباعة حالياً');
    } else {
      r = await ref.read(printJobRunnerProvider).printBlocks(
            blocks,
            title: 'مشاركة: ${_items.length} عنصر',
            stored: '',
          );
    }

    if (!mounted) return;
    setState(() {
      _printing = false;
      _ok = r.ok;
      final warning = unsupported.isEmpty
          ? ''
          : '\nلم تتم معالجة هذه الملفات بعد: ${unsupported.join('، ')}';
      _result = (r.ok ? 'تم إرسال العناصر المدعومة للطباعة' : 'فشلت الطباعة: ${r.error}') + warning;
    });
  }

  Widget _preview(SharedItem item) {
    if (item.isImage && item.bytes != null) {
      return ListTile(
        leading: SizedBox(
          width: 52,
          height: 52,
          child: Image.memory(item.bytes!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image)),
        ),
        title: Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: const Text('صورة جاهزة للطباعة'),
      );
    }
    if (item.kind == 'text' && item.text != null) {
      return ListTile(
        leading: const Icon(Icons.text_snippet_outlined),
        title: Text(item.name),
        subtitle: Text(_short(item.text!)),
      );
    }
    final ext = item.name.toLowerCase().split('.').last;
    final isPdf = ext == 'pdf';
    final isTabular = const ['csv', 'xlsx', 'txt', 'html', 'htm'].contains(ext);
    final isOfficeXml = const ['docx', 'pptx'].contains(ext);
    return ListTile(
      leading: const Icon(Icons.insert_drive_file_outlined),
      title: Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(isPdf ? 'ملف PDF — سيتم تحويل كل صفحة لصورة' : isTabular ? 'سيتم تحويل المحتوى إلى صفحات صور' : isOfficeXml ? 'سيتم استخراج النص وترتيبه للطباعة' : 'صيغة الملف لم تُجهّز للتحويل بعد'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final conn = ref.watch(connectionControllerProvider);
    final items = _items;

    return Scaffold(
      appBar: AppBar(title: const Text('طباعة المحتوى المشترك')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('الملفات المختارة: ${items.length}', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _printing ? null : _addFiles,
              icon: const Icon(Icons.add_to_photos_outlined),
              label: const Text('إضافة ملفات متعددة'),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Card(
                child: ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) => _preview(items[i]),
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (!conn.isConnected)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    const Expanded(child: Text('لا توجد طابعة متصلة')),
                    TextButton(onPressed: () => context.push('/connect'), child: const Text('اتصال')),
                  ],
                ),
              ),
            if (_result != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  _result!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: _ok ? Colors.green : Theme.of(context).colorScheme.error),
                ),
              ),
            FilledButton.icon(
              onPressed: (_printing || !conn.isConnected) ? null : _print,
              icon: _printing
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.print),
              label: Text(_ok ? 'إعادة الطباعة' : 'طباعة العناصر المدعومة'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              onPressed: () => context.canPop() ? context.pop() : context.go('/'),
              child: const Text('إغلاق'),
            ),
          ],
        ),
      ),
    );
  }
}
