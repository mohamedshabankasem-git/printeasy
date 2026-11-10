import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../connection/presentation/connection_controller.dart';
import '../../printing/data/print_job_runner.dart';
import '../../templates/domain/default_templates.dart';
import '../../share/presentation/share_listener.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final st = ref.watch(connectionControllerProvider);
    final ctrl = ref.read(connectionControllerProvider.notifier);
    final scheme = Theme.of(context).colorScheme;

    final connected = st.isConnected;
    final statusText = switch (st.status) {
      LinkStatus.connected => 'متصل: ${st.device?.name ?? ''}',
      LinkStatus.connecting => 'جارٍ الاتصال...',
      LinkStatus.error => st.error ?? 'خطأ في الاتصال',
      LinkStatus.disconnected => 'غير متصل بطابعة',
    };

    Widget tile(IconData icon, String label, VoidCallback onTap) => Card(
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 34, color: scheme.primary),
                const SizedBox(height: 8),
                Text(label),
              ],
            ),
          ),
        );

    return Scaffold(
      appBar: AppBar(title: const Text('طباعة سريعة')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: connected ? scheme.primaryContainer : scheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(connected ? Icons.print : Icons.print_disabled, size: 28),
                      const SizedBox(width: 12),
                      Expanded(child: Text(statusText, style: Theme.of(context).textTheme.titleMedium)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: [
                      FilledButton.tonal(
                        style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
                        onPressed: () => context.push('/connect'),
                        child: Text(connected ? 'تغيير الطابعة' : 'اختيار طابعة'),
                      ),
                      if (!connected && st.lastPrinter != null)
                        FilledButton.tonal(
                          style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
                          onPressed: st.status == LinkStatus.connecting ? null : ctrl.reconnectLast,
                          child: Text('إعادة الاتصال بـ ${st.lastPrinter!.name}'),
                        ),
                      if (connected)
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40)),
                          onPressed: ctrl.disconnect,
                          child: const Text('قطع الاتصال'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.25,
            children: [
              tile(Icons.receipt_long, 'فاتورة سريعة', () => context.push('/invoice')),
              tile(Icons.description_outlined, 'القوالب', () => context.push('/templates')),
              tile(Icons.table_chart_outlined, 'طباعة جماعية', () => context.push('/batch')),
              tile(Icons.folder_open_outlined, 'طباعة ملفات', () => context.push('/share', extra: const SharedPayload(items: []))),
              tile(Icons.history, 'السجل', () => context.push('/history')),
              tile(Icons.settings_outlined, 'الإعدادات', () => context.push('/settings')),
            ],
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            onPressed: !connected
                ? null
                : () async {
                    final r = await ref
                        .read(printJobRunnerProvider)
                        .printDsl(kTestPrintTemplate, title: 'طباعة تجريبية');
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(r.ok ? 'تمت الطباعة التجريبية' : 'فشلت الطباعة: ${r.error}')),
                      );
                    }
                  },
            icon: const Icon(Icons.print_outlined),
            label: const Text('طباعة تجريبية'),
          ),
        ],
      ),
    );
  }
}
