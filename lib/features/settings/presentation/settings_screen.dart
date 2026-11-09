import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'settings_providers.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late final TextEditingController _shop;

  @override
  void initState() {
    super.initState();
    _shop = TextEditingController(text: ref.read(settingsProvider).shopName);
  }

  @override
  void dispose() {
    _shop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(settingsProvider);
    final n = ref.read(settingsProvider.notifier);
    const densityLabels = ['فاتح', 'عادي', 'غامق'];

    return Scaffold(
      appBar: AppBar(title: const Text('الإعدادات')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('الطابعة', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          const Text('عرض الورق'),
          const SizedBox(height: 8),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 58, label: Text('58 مم')),
              ButtonSegment(value: 80, label: Text('80 مم')),
            ],
            selected: {s.paperWidthMm},
            onSelectionChanged: (v) => n.setPaperWidth(v.first),
          ),
          const SizedBox(height: 20),
          Text('كثافة الطباعة: ${densityLabels[s.density]}'),
          Slider(
            value: s.density.toDouble(),
            min: 0,
            max: 2,
            divisions: 2,
            label: densityLabels[s.density],
            onChanged: (v) => n.setDensity(v.round()),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('القص التلقائي'),
            value: s.autoCut,
            onChanged: n.setAutoCut,
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<int>(
            value: s.tailFeedMm,
            decoration: const InputDecoration(labelText: 'التغذية بعد الإيصال'),
            items: const [0, 5, 10, 15, 20]
                .map((v) => DropdownMenuItem(value: v, child: Text('$v مم')))
                .toList(),
            onChanged: (v) => v == null ? null : n.setTailFeed(v),
          ),
          const Divider(height: 40),
          Text('التطبيق', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          TextField(
            controller: _shop,
            decoration: const InputDecoration(labelText: 'اسم المتجر (يظهر في الفاتورة)'),
            onChanged: n.setShopName,
          ),
          const SizedBox(height: 16),
          const Text('المظهر'),
          const SizedBox(height: 8),
          SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(value: ThemeMode.system, label: Text('النظام')),
              ButtonSegment(value: ThemeMode.light, label: Text('نهاري')),
              ButtonSegment(value: ThemeMode.dark, label: Text('ليلي')),
            ],
            selected: {s.themeMode},
            onSelectionChanged: (v) => n.setThemeMode(v.first),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('الطباعة المباشرة من المشاركة'),
            subtitle: const Text('عند المشاركة إلى التطبيق تبدأ الطباعة فوراً دون تأكيد'),
            value: s.shareAutoPrint,
            onChanged: n.setShareAutoPrint,
          ),
        ],
      ),
    );
  }
}
