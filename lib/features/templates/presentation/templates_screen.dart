import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'templates_providers.dart';

class TemplatesScreen extends ConsumerWidget {
  const TemplatesScreen({super.key});

  void _chooseType(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.description_outlined),
              title: const Text('قالب نصي'),
              subtitle: const Text('أوامر ومتغيرات بسيطة'),
              onTap: () {
                c.pop();
                context.push('/templates/edit');
              },
            ),
            ListTile(
              leading: const Icon(Icons.dashboard_customize_outlined),
              title: const Text('قالب مرئي'),
              subtitle: const Text('سحب وإفلات نص وصورة وQR'),
              onTap: () {
                c.pop();
                context.push('/visual-editor');
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(templatesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('القوالب')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _chooseType(context),
        icon: const Icon(Icons.add),
        label: const Text('قالب جديد'),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('خطأ: $e')),
        data: (list) {
          if (list.isEmpty) return const Center(child: Text('لا توجد قوالب بعد'));
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
            itemCount: list.length,
            itemBuilder: (context, i) {
              final t = list[i];
              return Card(
                child: ListTile(
                  leading: Icon(t.type == 'visual' ? Icons.dashboard_customize_outlined : Icons.description_outlined),
                  title: Text(t.name),
                  subtitle: Text(
                    t.type == 'visual'
                        ? 'قالب مرئي'
                        : t.content.split('\n').where((l) => !l.startsWith('#')).take(2).join(' • '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () => context.push(
                    t.type == 'visual' ? '/visual-editor' : '/templates/edit',
                    extra: t,
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () async {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (c) => AlertDialog(
                          title: const Text('حذف القالب'),
                          content: Text('هل تريد حذف "${t.name}"؟'),
                          actions: [
                            TextButton(onPressed: () => c.pop(false), child: const Text('إلغاء')),
                            FilledButton(
                              style: FilledButton.styleFrom(minimumSize: const Size(80, 40)),
                              onPressed: () => c.pop(true),
                              child: const Text('حذف'),
                            ),
                          ],
                        ),
                      );
                      if (ok == true && t.id != null) {
                        await ref.read(templatesProvider.notifier).remove(t.id!);
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
