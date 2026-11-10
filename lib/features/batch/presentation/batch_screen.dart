import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/printing/visual_layout.dart';
import '../../connection/presentation/connection_controller.dart';
import '../../printing/data/print_job_runner.dart';
import '../../templates/domain/template_dsl.dart';
import '../../templates/domain/template_model.dart';
import '../../templates/presentation/templates_providers.dart';
import '../data/batch_file_parser.dart';

class BatchScreen extends ConsumerStatefulWidget {
  const BatchScreen({super.key});

  @override
  ConsumerState<BatchScreen> createState() => _BatchScreenState();
}

class _BatchScreenState extends ConsumerState<BatchScreen> {
  String? _fileName;
  List<String> _headers = [];
  List<List<String>> _rows = [];
  TemplateModel? _template;
  Map<String, String?> _mapping = {};

  bool _running = false;
  bool _cancel = false;
  int _done = 0;
  int _failed = 0;
  String? _message;

  List<String> _variablesOf(TemplateModel t) =>
      VisualLayout.tryParse(t.content)?.variables ?? TemplateDsl.variablesOf(t.content);

  static String _norm(String s) => s.toLowerCase().replaceAll(RegExp(r'[\s_\-]+'), '');

  /// ربط تلقائي: اسم المتغير = اسم العمود (بدون اعتبار المسافات و_ وحالة الأحرف)
  void _autoMap() {
    final t = _template;
    if (t == null) return;
    final map = <String, String?>{};
    for (final v in _variablesOf(t)) {
      String? match;
      for (final h in _headers) {
        if (_norm(h) == _norm(v)) {
          match = h;
          break;
        }
      }
      map[v] = match;
    }
    _mapping = map;
  }

  Future<void> _pickFile() async {
    final r = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['csv', 'xlsx'],
      withData: true,
    );
    if (r == null || r.files.isEmpty) return;
    final f = r.files.single;
    final bytes = f.bytes;
    if (bytes == null) {
      setState(() => _message = 'تعذرت قراءة الملف');
      return;
    }
    try {
      final table = BatchFileParser.parse(f.name, bytes);
      setState(() {
        _fileName = f.name;
        _headers = table.headers;
        _rows = table.rows;
        _message = null;
        _done = 0;
        _failed = 0;
        _autoMap();
      });
    } catch (e) {
      setState(() => _message = 'خطأ في قراءة الملف: ${e.toString().replaceFirst('Exception: ', '')}');
    }
  }

  Map<String, String> _rowVars(List<String> row) {
    final vars = <String, String>{};
    _mapping.forEach((v, header) {
      if (header == null) return;
      final i = _headers.indexOf(header);
      if (i >= 0 && i < row.length) vars[v] = row[i].replaceAll('\n', ' ');
    });
    return vars;
  }

  Future<void> _start() async {
    final t = _template;
    if (t == null || _rows.isEmpty) return;
    if (!ref.read(connectionControllerProvider).isConnected) {
      setState(() => _message = 'اتصل بطابعة أولاً');
      return;
    }
    final runner = ref.read(printJobRunnerProvider);
    setState(() {
      _running = true;
      _cancel = false;
      _done = 0;
      _failed = 0;
      _message = null;
    });

    for (var i = 0; i < _rows.length; i++) {
      if (_cancel) break;
      final r = await runner.printContent(
        t.content,
        vars: _rowVars(_rows[i]),
        title: 'جماعية ${i + 1}/${_rows.length} - ${t.name}',
      );
      if (!mounted) return;
      if (!r.ok && r.error == kNoPrinterError) {
        setState(() {
          _failed++;
          _message = 'انقطع الاتصال بالطابعة — تم الإيقاف';
        });
        break;
      }
      setState(() {
        if (r.ok) {
          _done++;
        } else {
          _failed++;
        }
      });
      await Future.delayed(const Duration(milliseconds: 300));
    }

    if (!mounted) return;
    setState(() {
      _running = false;
      _message ??= _cancel ? 'تم الإلغاء' : 'اكتملت الطباعة';
    });
  }

  @override
  Widget build(BuildContext context) {
    final templates = ref.watch(templatesProvider).valueOrNull ?? const <TemplateModel>[];
    final connected = ref.watch(connectionControllerProvider).isConnected;
    final total = _rows.length;
    final processed = _done + _failed;

    return Scaffold(
      appBar: AppBar(title: const Text('الطباعة الجماعية')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (!connected)
            Card(
              child: ListTile(
                leading: const Icon(Icons.print_disabled),
                title: const Text('لا توجد طابعة متصلة'),
                trailing: TextButton(onPressed: () => context.push('/connect'), child: const Text('اتصال')),
              ),
            ),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            onPressed: _running ? null : _pickFile,
            icon: const Icon(Icons.upload_file),
            label: Text(_fileName == null ? 'اختيار ملف CSV أو Excel' : '$_fileName • $total صف'),
          ),
          if (_headers.isNotEmpty) ...[
            const SizedBox(height: 16),
            DropdownButtonFormField<TemplateModel>(
              key: ValueKey(_template?.id),
              initialValue: templates.any((t) => t.id == _template?.id) ? _template : null,
              decoration: const InputDecoration(labelText: 'القالب'),
              items: templates.map((t) => DropdownMenuItem(value: t, child: Text(t.name))).toList(),
              onChanged: _running
                  ? null
                  : (v) => setState(() {
                        _template = v;
                        _autoMap();
                      }),
            ),
            if (_template != null) ...[
              const SizedBox(height: 16),
              Text('ربط الأعمدة بالمتغيرات', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              if (_mapping.isEmpty) const Text('هذا القالب لا يحتوي متغيرات {key} — ستُطبع نسخة متطابقة لكل صف.'),
              for (final v in _mapping.keys)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: DropdownButtonFormField<String?>(
                    key: ValueKey('$v-${_mapping[v]}'),
                    initialValue: _mapping[v],
                    decoration: InputDecoration(labelText: '{$v}', isDense: true),
                    items: [
                      const DropdownMenuItem<String?>(value: null, child: Text('— بدون —')),
                      for (final h in _headers) DropdownMenuItem<String?>(value: h, child: Text(h)),
                    ],
                    onChanged: _running ? null : (h) => setState(() => _mapping[v] = h),
                  ),
                ),
            ],
          ],
          if (_running || processed > 0) ...[
            const SizedBox(height: 16),
            LinearProgressIndicator(value: total == 0 ? 0 : processed / total),
            const SizedBox(height: 8),
            Text('تمت $_done من $total${_failed > 0 ? ' • فشل $_failed' : ''}'),
          ],
          if (_message != null) ...[
            const SizedBox(height: 8),
            Text(_message!),
          ],
          const SizedBox(height: 20),
          if (_running)
            FilledButton.tonalIcon(
              onPressed: () => setState(() => _cancel = true),
              icon: const Icon(Icons.stop),
              label: const Text('إلغاء'),
            )
          else
            FilledButton.icon(
              onPressed: (_template == null || _rows.isEmpty || !connected) ? null : _start,
              icon: const Icon(Icons.print),
              label: Text('بدء الطباعة ($total)'),
            ),
        ],
      ),
    );
  }
}
