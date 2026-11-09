import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../printing/data/print_job_runner.dart';
import 'history_providers.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(historyProvider);
    final fmt = DateFormat('yyyy-MM-dd HH:mm');

    return Scaffold(
      appBar: AppBar(
        title: const Text('السجل'),
        actions: [
          IconButton(
            tooltip: 'مسح الكل',
            icon: const Icon(Icons.delete_sweep_outlined),
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (c) => AlertDialog(
                  title: const Text('مسح السجل'),
                  content: const Text('سيتم حذف كل العمليات المسجلة.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('إلغاء')),
                    TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('مسح')),
                  ],
                ),
              );
              if (ok == true) await ref.read(historyProvider.notifier).clearAll();
            },
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('خطأ: $e')),
        data: (list) {
          if (list.isEmpty) return const Center(child: Text('لا توجد عمليات طباعة بعد'));
          return ListView.separated(
            itemCount: list.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final e = list[i];
              return Dismissible(
                key: ValueKey(e.id),
                background: Container(color: Colors.red.shade400),
                onDismissed: (_) => ref.read(historyProvider.notifier).remove(e.id!),
                child: ListTile(
                  leading: Icon(
                    e.success ? Icons.check_circle : Icons.error,
                    color: e.success ? Colors.green : Theme.of(context).colorScheme.error,
                  ),
                  title: Text(e.title),
                  subtitle: Text(
                    e.success ? fmt.format(e.createdAt) : '${fmt.format(e.createdAt)} • ${e.error ?? 'فشل'}',
                  ),
                  trailing: IconButton(
                    tooltip: 'إعادة الطباعة',
                    icon: const Icon(Icons.replay),
                    onPressed: e.content.isEmpty
                        ? null
                        : () async {
                      final r = await ref
                          .read(printJobRunnerProvider)
                          .printDsl(e.content, title: e.title);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(r.ok ? 'تمت الطباعة' : 'فشلت الطباعة: ${r.error}')),
                        );
                      }
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
