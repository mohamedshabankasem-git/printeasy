import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/printing/print_block.dart';
import '../../connection/presentation/connection_controller.dart';
import '../../printing/data/print_job_runner.dart';
import '../../settings/presentation/settings_providers.dart';
import 'share_listener.dart';

/// شاشة الطباعة من المشاركة. إن فُعّلت "الطباعة المباشرة" في الإعدادات
/// وكانت الطابعة متصلة، تبدأ الطباعة فور الفتح.
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

  /// أسطر تبدأ بـ # تُهرَّب حتى لا تُفسَّر كأوامر قالب عند إعادة الطباعة
  String _escape(String text) => text
      .split('\n')
      .map((l) => l.trimLeft().startsWith('#') ? '\\${l.trimLeft()}' : l)
      .join('\n');

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
    final runner = ref.read(printJobRunnerProvider);
    final p = widget.payload;
    final PrintResult r;

    if (p.imageBytes != null) {
      r = await runner.printBlocks(
        [ImageBlock(p.imageBytes!), const FeedBlock(26)],
        title: 'صورة مشتركة',
        stored: '', // الصور لا تُحفظ، فلا تتوفر إعادة الطباعة
      );
    } else {
      final text = p.text ?? '';
      final blocks = <PrintBlock>[
        for (final l in text.split('\n')) TextBlock(l),
        const FeedBlock(26),
      ];
      r = await runner.printBlocks(
        blocks,
        title: 'نص مشترك: ${_short(text)}',
        stored: _escape(text),
      );
    }

    if (!mounted) return;
    setState(() {
      _printing = false;
      _ok = r.ok;
      _result = r.ok ? 'تمت الطباعة' : 'فشلت الطباعة: ${r.error}';
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.payload;
    final conn = ref.watch(connectionControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('طباعة المحتوى المشترك')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Card(
                child: p.imageBytes != null
                    ? Padding(
                        padding: const EdgeInsets.all(8),
                        child: Image.memory(p.imageBytes!, fit: BoxFit.contain),
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: SelectableText(p.text ?? '', style: const TextStyle(fontSize: 16)),
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
              label: Text(_ok ? 'طباعة مرة أخرى' : 'طباعة'),
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
