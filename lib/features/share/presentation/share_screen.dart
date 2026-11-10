import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/printing/print_block.dart';
import '../../../core/files/pdf_page_converter.dart';
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

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      final auto = ref.read(settingsProvider).shareAutoPrint;
      final connected = ref.read(connectionControllerProvider).isConnected;
      if (auto && connected) await _print();
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
      for (final item in widget.payload.items) {
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
            title: 'مشاركة: ${widget.payload.items.length} عنصر',
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
    final isPdf = item.name.toLowerCase().endsWith('.pdf');
    return ListTile(
      leading: const Icon(Icons.insert_drive_file_outlined),
      title: Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(isPdf ? 'ملف PDF — سيتم تحويل كل صفحة لصورة' : 'صيغة الملف لم تُجهّز للتحويل بعد'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final conn = ref.watch(connectionControllerProvider);
    final items = widget.payload.items;

    return Scaffold(
      appBar: AppBar(title: const Text('طباعة المحتوى المشترك')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('العناصر المستلمة: ${items.length}', style: Theme.of(context).textTheme.titleMedium),
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
