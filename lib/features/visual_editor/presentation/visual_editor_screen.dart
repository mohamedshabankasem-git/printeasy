import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../core/printing/escpos_commands.dart';
import '../../../core/printing/receipt_renderer.dart';
import '../../../core/printing/visual_layout.dart';
import '../../../core/printing/visual_renderer.dart';
import '../../settings/presentation/settings_providers.dart';
import '../../templates/domain/template_model.dart';
import '../../templates/presentation/templates_providers.dart';

/// المحرر المرئي: سحب وإفلات عناصر (نص، صورة، QR، خط) على ورقة بعرض الطابعة.
/// الإحداثيات تُخزَّن بالنقاط، والعرض على الشاشة = النقاط × scale.
class VisualEditorScreen extends ConsumerStatefulWidget {
  const VisualEditorScreen({super.key, this.template});
  final TemplateModel? template;

  @override
  ConsumerState<VisualEditorScreen> createState() => _VisualEditorScreenState();
}

class _VisualEditorScreenState extends ConsumerState<VisualEditorScreen> {
  late VisualLayout _layout;
  late final TextEditingController _name;
  final TextEditingController _textCtrl = TextEditingController();
  String? _selectedId;
  bool _dragging = false;

  static const _variables = ['shop_name', 'date', 'invoice_no', 'customer_name', 'items', 'total'];

  int get _widthDots => ref.read(settingsProvider).toPrintSettings().widthDots;

  VisualElement? get _sel => _layout.elements.where((e) => e.id == _selectedId).firstOrNull;

  @override
  void initState() {
    super.initState();
    _layout = VisualLayout.tryParse(widget.template?.content ?? '') ?? VisualLayout();
    _name = TextEditingController(text: widget.template?.name ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _textCtrl.dispose();
    super.dispose();
  }

  void _select(String? id) {
    setState(() => _selectedId = id);
    final e = _sel;
    _textCtrl.text = e?.text ?? '';
  }

  // ---------- إضافة العناصر ----------
  void _add(VisualType t, {String? imageB64}) {
    final w = _widthDots.toDouble();
    final y = _layout.elements.fold<double>(8, (m, e) => math.max(m, e.y + e.h + 8));
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final el = switch (t) {
      VisualType.text => VisualElement(id: id, type: t, x: 10, y: y, w: w - 20, h: 40, text: 'نص جديد'),
      VisualType.qr => VisualElement(id: id, type: t, x: (w - 140) / 2, y: y, w: 140, h: 140, text: '{invoice_no}'),
      VisualType.image => VisualElement(id: id, type: t, x: (w - 160) / 2, y: y, w: 160, h: 100, imageB64: imageB64),
      VisualType.line => VisualElement(id: id, type: t, x: 10, y: y, w: w - 20, h: 12),
    };
    setState(() {
      _layout.elements.add(el);
      if (el.y + el.h + 12 > _layout.height) _layout.height = el.y + el.h + 12;
    });
    _select(id);
  }

  Future<void> _addImage() async {
    final r = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
    final bytes = r?.files.single.bytes;
    if (bytes == null) return;
    _add(VisualType.image, imageB64: base64Encode(bytes));
  }

  void _deleteSelected() {
    final e = _sel;
    if (e == null) return;
    setState(() => _layout.elements.remove(e));
    _select(null);
  }

  // ---------- الحفظ والمعاينة ----------
  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('أدخل اسم القالب')));
      return;
    }
    final now = DateTime.now();
    final old = widget.template;
    final t = old == null
        ? TemplateModel(name: name, type: 'visual', content: _layout.toJsonString(), createdAt: now, updatedAt: now)
        : old.copyWith(name: name, content: _layout.toJsonString(), updatedAt: now);
    await ref.read(templatesProvider.notifier).save(t);
    if (mounted) context.pop();
  }

  String _sample(String v) => switch (v) {
        'shop_name' => ref.read(settingsProvider).shopName,
        'date' => '2026-01-01 12:00',
        'invoice_no' => 'INV-0001',
        'customer_name' => 'عميل تجريبي',
        'items' => '#row:صنف تجريبي × 2|20.00\n#row:صنف آخر × 1|15.50',
        'total' => '35.50',
        _ => '[$v]',
      };

  Future<void> _preview() async {
    try {
      final vars = {for (final v in _layout.variables) v: _sample(v)};
      final img = await VisualRenderer(widthDots: _widthDots).render(_layout.filled(vars));
      final bd = await img.toByteData(format: ui.ImageByteFormat.png);
      img.dispose();
      if (bd == null || !mounted) return;
      await showDialog<void>(
        context: context,
        builder: (c) => Dialog(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: Container(color: Colors.white, child: Image.memory(bd.buffer.asUint8List())),
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذرت المعاينة: $e')));
      }
    }
  }

  // ---------- رسم العناصر على الشاشة ----------
  Widget _content(VisualElement e, double s) {
    switch (e.type) {
      case VisualType.text:
        final arabic = ReceiptRenderer.isArabic(e.text);
        return ClipRect(
          child: Directionality(
            textDirection: arabic ? TextDirection.rtl : TextDirection.ltr,
            child: Text(
              e.text,
              textAlign: switch (e.align) {
                PrintAlign.left => TextAlign.left,
                PrintAlign.center => TextAlign.center,
                PrintAlign.right => TextAlign.right,
              },
              style: TextStyle(
                color: Colors.black,
                fontSize: 24.0 * e.size * s,
                fontWeight: e.bold ? FontWeight.w900 : FontWeight.w600,
                height: 1.25,
              ),
            ),
          ),
        );
      case VisualType.qr:
        final side = math.min(e.w, e.h) * s;
        return Center(
          child: QrImageView(
            data: e.text.isEmpty ? ' ' : e.text,
            size: side,
            padding: EdgeInsets.zero,
            backgroundColor: Colors.white,
          ),
        );
      case VisualType.image:
        return e.imageB64 == null
            ? const Icon(Icons.image_outlined, color: Colors.grey)
            : Image.memory(base64Decode(e.imageB64!), fit: BoxFit.contain, gaplessPlayback: true);
      case VisualType.line:
        return Center(child: Container(height: 2 * s, color: Colors.black));
    }
  }

  Widget _element(VisualElement e, double s, Color primary) {
    final selected = e.id == _selectedId;
    final maxX = math.max(0.0, _widthDots - e.w);
    return Positioned(
      left: e.x * s,
      top: e.y * s,
      width: e.w * s,
      height: e.h * s,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _select(e.id),
        onPanStart: (_) {
          _select(e.id);
          setState(() => _dragging = true);
        },
        onPanUpdate: (d) => setState(() {
          e.x = (e.x + d.delta.dx / s).clamp(0.0, maxX);
          e.y = math.max(0, e.y + d.delta.dy / s);
          if (e.y + e.h > _layout.height) _layout.height = e.y + e.h;
        }),
        onPanEnd: (_) => setState(() => _dragging = false),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(child: _content(e, s)),
            if (selected) ...[
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(border: Border.all(color: primary, width: 1.5)),
                  ),
                ),
              ),
              // مقبض تغيير الحجم (أسفل اليمين)
              Positioned(
                right: 0,
                bottom: 0,
                child: GestureDetector(
                  onPanStart: (_) => setState(() => _dragging = true),
                  onPanEnd: (_) => setState(() => _dragging = false),
                  onPanUpdate: (d) => setState(() {
                    e.w = (e.w + d.delta.dx / s).clamp(30.0, _widthDots - e.x);
                    e.h = math.max(10, e.h + d.delta.dy / s);
                    if (e.y + e.h > _layout.height) _layout.height = e.y + e.h;
                  }),
                  child: Container(
                    width: 22,
                    height: 22,
                    color: primary,
                    child: const Icon(Icons.open_in_full, size: 14, color: Colors.white),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _panel(VisualElement e) {
    final isText = e.type == VisualType.text;
    final hasText = isText || e.type == VisualType.qr;
    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasText)
              TextField(
                controller: _textCtrl,
                maxLines: isText ? 3 : 1,
                minLines: 1,
                decoration: InputDecoration(
                  isDense: true,
                  labelText: isText ? 'النص' : 'بيانات QR',
                ),
                onChanged: (v) => setState(() => e.text = v),
              ),
            if (hasText)
              SizedBox(
                height: 38,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final v in _variables)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(end: 6, top: 4),
                        child: ActionChip(
                          label: Text('{$v}'),
                          visualDensity: VisualDensity.compact,
                          onPressed: () {
                            setState(() => e.text = '${e.text}{$v}');
                            _textCtrl.text = e.text;
                          },
                        ),
                      ),
                  ],
                ),
              ),
            if (isText) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  FilterChip(
                    label: const Text('عريض'),
                    selected: e.bold,
                    onSelected: (v) => setState(() => e.bold = v),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SegmentedButton<int>(
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment(value: 1, label: Text('1')),
                        ButtonSegment(value: 2, label: Text('2')),
                        ButtonSegment(value: 3, label: Text('3')),
                        ButtonSegment(value: 4, label: Text('4')),
                      ],
                      selected: {e.size},
                      onSelectionChanged: (v) => setState(() => e.size = v.first),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              SegmentedButton<PrintAlign>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: PrintAlign.left, icon: Icon(Icons.format_align_left)),
                  ButtonSegment(value: PrintAlign.center, icon: Icon(Icons.format_align_center)),
                  ButtonSegment(value: PrintAlign.right, icon: Icon(Icons.format_align_right)),
                ],
                selected: {e.align},
                onSelectionChanged: (v) => setState(() => e.align = v.first),
              ),
            ],
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton.icon(
                onPressed: _deleteSelected,
                icon: const Icon(Icons.delete_outline),
                label: const Text('حذف العنصر'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final sel = _sel;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.template == null ? 'قالب مرئي جديد' : 'تعديل القالب المرئي'),
        actions: [
          IconButton(tooltip: 'معاينة', onPressed: _preview, icon: const Icon(Icons.visibility_outlined)),
          IconButton(tooltip: 'حفظ', onPressed: _save, icon: const Icon(Icons.check)),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: TextField(
              controller: _name,
              decoration: const InputDecoration(isDense: true, labelText: 'اسم القالب'),
            ),
          ),
          SizedBox(
            height: 46,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                ActionChip(avatar: const Icon(Icons.text_fields, size: 18), label: const Text('نص'), onPressed: () => _add(VisualType.text)),
                const SizedBox(width: 6),
                ActionChip(avatar: const Icon(Icons.qr_code, size: 18), label: const Text('QR'), onPressed: () => _add(VisualType.qr)),
                const SizedBox(width: 6),
                ActionChip(avatar: const Icon(Icons.image_outlined, size: 18), label: const Text('صورة'), onPressed: _addImage),
                const SizedBox(width: 6),
                ActionChip(avatar: const Icon(Icons.horizontal_rule, size: 18), label: const Text('خط'), onPressed: () => _add(VisualType.line)),
                const SizedBox(width: 12),
                IconButton(
                  tooltip: 'تقليل الارتفاع',
                  onPressed: () => setState(() => _layout.height = math.max(100, _layout.height - 50)),
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                Center(child: Text('${_layout.height.round()}')),
                IconButton(
                  tooltip: 'زيادة الارتفاع',
                  onPressed: () => setState(() => _layout.height += 50),
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, cons) {
                final s = (cons.maxWidth - 24) / _widthDots;
                return SingleChildScrollView(
                  physics: _dragging ? const NeverScrollableScrollPhysics() : null,
                  padding: const EdgeInsets.all(12),
                  child: GestureDetector(
                    onTap: () => _select(null),
                    child: Container(
                      width: _widthDots * s,
                      height: _layout.height * s,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: Colors.black26),
                        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
                      ),
                      clipBehavior: Clip.hardEdge,
                      child: Stack(
                        clipBehavior: Clip.hardEdge,
                        children: [for (final e in _layout.elements) _element(e, s, primary)],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (sel != null) SafeArea(top: false, child: _panel(sel)),
        ],
      ),
    );
  }
}
