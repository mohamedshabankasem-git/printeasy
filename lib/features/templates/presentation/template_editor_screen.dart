import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/printing/receipt_renderer.dart';
import '../../settings/presentation/settings_providers.dart';
import '../domain/template_dsl.dart';
import '../domain/template_model.dart';
import 'templates_providers.dart';

class TemplateEditorScreen extends ConsumerStatefulWidget {
  const TemplateEditorScreen({super.key, this.template});
  final TemplateModel? template;

  @override
  ConsumerState<TemplateEditorScreen> createState() => _TemplateEditorScreenState();
}

class _TemplateEditorScreenState extends ConsumerState<TemplateEditorScreen> {
  late final TextEditingController _name;
  late final TextEditingController _content;

  static const _commands = <String, String>{
    'وسط': '#align:center\n',
    'يمين': '#align:right\n',
    'يسار': '#align:left\n',
    'عريض': '#bold\n',
    'عادي': '#bold:off\n',
    'حجم 2': '#size:2\n',
    'حجم 1': '#size:1\n',
    'فاصل': '#sep\n',
    'صف': '#row:الصنف|السعر\n',
    'QR': '#qr:{invoice_no}\n',
    'باركود': '#barcode:123456\n',
    'تغذية': '#feed:1\n',
    'قص': '#cut\n',
  };

  static const _variables = ['shop_name', 'date', 'invoice_no', 'customer_name', 'items', 'total'];

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.template?.name ?? '');
    _content = TextEditingController(text: widget.template?.content ?? '#align:center\n');
  }

  @override
  void dispose() {
    _name.dispose();
    _content.dispose();
    super.dispose();
  }

  /// إدراج نص عند موضع المؤشر
  void _insert(String s) {
    final sel = _content.selection;
    final t = _content.text;
    final start = sel.isValid ? sel.start : t.length;
    final end = sel.isValid ? sel.end : t.length;
    _content.value = TextEditingValue(
      text: t.replaceRange(start, end, s),
      selection: TextSelection.collapsed(offset: start + s.length),
    );
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('أدخل اسم القالب')));
      return;
    }
    final now = DateTime.now();
    final old = widget.template;
    final t = old == null
        ? TemplateModel(name: name, content: _content.text, createdAt: now, updatedAt: now)
        : old.copyWith(name: name, content: _content.text, updatedAt: now);
    await ref.read(templatesProvider.notifier).save(t);
    if (mounted) context.pop();
  }

  Future<void> _preview() async {
    try {
      final settings = ref.read(settingsProvider);
      // نعوّض المتغيرات بقيم تجريبية لتظهر في المعاينة
      final vars = {
        for (final v in TemplateDsl.variablesOf(_content.text)) v: _sample(v, settings.shopName),
      };
      final blocks = TemplateDsl.parse(_content.text, vars: vars);
      final img = await ReceiptRenderer(widthDots: settings.toPrintSettings().widthDots).render(blocks);
      final bd = await img.toByteData(format: ui.ImageByteFormat.png);
      img.dispose();
      if (bd == null || !mounted) return;
      await showDialog<void>(
        context: context,
        builder: (c) => Dialog(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: Container(
              color: Colors.white,
              child: Image.memory(bd.buffer.asUint8List()),
            ),
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذرت المعاينة: $e')));
      }
    }
  }

  String _sample(String v, String shop) => switch (v) {
        'shop_name' => shop,
        'date' => '2026-01-01 12:00',
        'invoice_no' => 'INV-0001',
        'customer_name' => 'عميل تجريبي',
        'items' => '#row:صنف تجريبي × 2|20.00\n#row:صنف آخر × 1|15.50',
        'total' => '35.50',
        _ => '[$v]',
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.template == null ? 'قالب جديد' : 'تعديل القالب'),
        actions: [
          IconButton(tooltip: 'معاينة', onPressed: _preview, icon: const Icon(Icons.visibility_outlined)),
          IconButton(tooltip: 'حفظ', onPressed: _save, icon: const Icon(Icons.check)),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            TextField(controller: _name, decoration: const InputDecoration(labelText: 'اسم القالب')),
            const SizedBox(height: 10),
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final e in _commands.entries)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(end: 6),
                      child: ActionChip(label: Text(e.key), onPressed: () => _insert(e.value)),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final v in _variables)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(end: 6),
                      child: ActionChip(
                        avatar: const Icon(Icons.data_object, size: 16),
                        label: Text('{$v}'),
                        onPressed: () => _insert('{$v}'),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: TextField(
                controller: _content,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                keyboardType: TextInputType.multiline,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 15),
                decoration: const InputDecoration(
                  alignLabelWithHint: true,
                  labelText: 'نص القالب',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
