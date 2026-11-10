import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../printing/data/print_job_runner.dart';
import '../../settings/presentation/settings_providers.dart';
import '../../templates/domain/default_templates.dart';
import '../../templates/domain/template_model.dart';
import '../../templates/presentation/templates_providers.dart';
import '../domain/invoice_models.dart';

class InvoiceScreen extends ConsumerStatefulWidget {
  const InvoiceScreen({super.key});

  @override
  ConsumerState<InvoiceScreen> createState() => _InvoiceScreenState();
}

class _InvoiceScreenState extends ConsumerState<InvoiceScreen> {
  final _customer = TextEditingController();
  final _itemName = TextEditingController();
  final _qty = TextEditingController(text: '1');
  final _price = TextEditingController();
  final List<InvoiceItem> _items = [];
  TemplateModel? _template;
  bool _printing = false;

  double get _total => _items.fold(0, (s, i) => s + i.lineTotal);

  @override
  void dispose() {
    _customer.dispose();
    _itemName.dispose();
    _qty.dispose();
    _price.dispose();
    super.dispose();
  }

  void _addItem() {
    final name = _itemName.text.trim();
    final qty = double.tryParse(_qty.text.trim().replaceAll(',', '.'));
    final price = double.tryParse(_price.text.trim().replaceAll(',', '.'));
    if (name.isEmpty || qty == null || price == null || qty <= 0) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('أدخل اسم الصنف والكمية والسعر بشكل صحيح')));
      return;
    }
    setState(() {
      _items.add(InvoiceItem(name: name, qty: qty, price: price));
      _itemName.clear();
      _qty.text = '1';
      _price.clear();
    });
  }

  Future<void> _print(List<TemplateModel> templates) async {
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('أضف صنفاً واحداً على الأقل')));
      return;
    }
    final now = DateTime.now();
    final invoiceNo = 'INV-${DateFormat('yyMMddHHmmss').format(now)}';
    final customer = _customer.text.trim().isEmpty ? 'عميل نقدي' : _customer.text.trim();
    final items = _items
        .map((i) => '#row:${i.safeName} × ${fmtNum(i.qty)}|${fmtNum(i.lineTotal)}')
        .join('\n');
    final vars = {
      'shop_name': ref.read(settingsProvider).shopName,
      'date': DateFormat('yyyy-MM-dd HH:mm').format(now),
      'invoice_no': invoiceNo,
      'customer_name': customer,
      'items': items,
      'total': fmtNum(_total),
    };
    final content = (_template ?? (templates.isNotEmpty ? templates.first : null))?.content ??
        kDefaultInvoiceTemplate;

    setState(() => _printing = true);
    final r = await ref
        .read(printJobRunnerProvider)
        .printDsl(content, vars: vars, title: 'فاتورة $invoiceNo - $customer');
    if (!mounted) return;
    setState(() => _printing = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(r.ok ? 'تمت الطباعة وحُفظت في السجل' : 'فشلت الطباعة: ${r.error}')),
    );
    if (r.ok) {
      setState(() {
        _items.clear();
        _customer.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final templates = ref.watch(templatesProvider).valueOrNull ?? const <TemplateModel>[];
    final selected = templates.any((t) => t.id == _template?.id) ? _template : null;

    return Scaffold(
      appBar: AppBar(title: const Text('فاتورة سريعة')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(controller: _customer, decoration: const InputDecoration(labelText: 'اسم العميل')),
          const SizedBox(height: 12),
          if (templates.isNotEmpty)
            DropdownButtonFormField<TemplateModel>(
              key: ValueKey(selected?.id ?? templates.first.id),
              initialValue: selected ?? templates.first,
              decoration: const InputDecoration(labelText: 'القالب'),
              items: templates.map((t) => DropdownMenuItem(value: t, child: Text(t.name))).toList(),
              onChanged: (v) => setState(() => _template = v),
            ),
          const SizedBox(height: 20),
          Text('إضافة صنف', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          TextField(controller: _itemName, decoration: const InputDecoration(labelText: 'اسم الصنف')),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _qty,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'الكمية'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _price,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'السعر'),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(onPressed: _addItem, icon: const Icon(Icons.add)),
            ],
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < _items.length; i++)
            Card(
              child: ListTile(
                title: Text(_items[i].name),
                subtitle: Text('${fmtNum(_items[i].qty)} × ${fmtNum(_items[i].price)}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(fmtNum(_items[i].lineTotal), style: const TextStyle(fontWeight: FontWeight.bold)),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(() => _items.removeAt(i)),
                    ),
                  ],
                ),
              ),
            ),
          const Divider(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('الإجمالي', style: Theme.of(context).textTheme.titleLarge),
              Text(fmtNum(_total), style: Theme.of(context).textTheme.titleLarge),
            ],
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _printing ? null : () => _print(templates),
            icon: _printing
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.print),
            label: const Text('طباعة الفاتورة'),
          ),
        ],
      ),
    );
  }
}
