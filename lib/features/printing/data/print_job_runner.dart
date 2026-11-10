import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/printing/print_block.dart';
import '../../../core/printing/print_service.dart';
import '../../../core/printing/visual_layout.dart';
import '../../../core/printing/visual_renderer.dart';
import '../../connection/presentation/connection_controller.dart';
import '../../history/domain/history_entry.dart';
import '../../history/presentation/history_providers.dart';
import '../../settings/presentation/settings_providers.dart';
import '../../templates/domain/template_dsl.dart';

class PrintResult {
  const PrintResult.ok() : ok = true, error = null;
  const PrintResult.fail(this.error) : ok = false;
  final bool ok;
  final String? error;
}

const String kNoPrinterError = 'لا توجد طابعة متصلة';

final printJobRunnerProvider = Provider<PrintJobRunner>((ref) => PrintJobRunner(ref));

/// ينفّذ مهمة طباعة كاملة ثم يسجلها في السجل. يدعم: قالب DSL، قالب مرئي (JSON)، وعناصر جاهزة.
class PrintJobRunner {
  PrintJobRunner(this._ref);
  final Ref _ref;

  /// للتوافق مع الاستدعاءات القديمة
  Future<PrintResult> printDsl(
    String content, {
    Map<String, String> vars = const {},
    String title = 'طباعة',
    bool log = true,
  }) =>
      printContent(content, vars: vars, title: title, log: log);

  /// يكتشف نوع المحتوى تلقائياً: JSON مرئي أو DSL نصي
  Future<PrintResult> printContent(
    String content, {
    Map<String, String> vars = const {},
    String title = 'طباعة',
    bool log = true,
  }) async {
    final visual = VisualLayout.tryParse(content);
    if (visual != null) {
      final filled = visual.filled(vars);
      return _run(
        (svc) async {
          final img = await VisualRenderer(widthDots: svc.settings.widthDots).render(filled);
          try {
            await svc.printImageJob(img);
          } finally {
            img.dispose();
          }
        },
        stored: filled.toJsonString(),
        title: title,
        log: log,
      );
    }
    final filled = TemplateDsl.fill(content, vars);
    return _run(
      (svc) => svc.printBlocks(TemplateDsl.parse(filled)),
      stored: filled,
      title: title,
      log: log,
    );
  }

  /// طباعة عناصر جاهزة (مثل الصور المشتركة). stored فارغ = لا تدعم إعادة الطباعة
  Future<PrintResult> printBlocks(
    List<PrintBlock> blocks, {
    String title = 'طباعة',
    String stored = '',
    bool log = true,
  }) =>
      _run((svc) => svc.printBlocks(blocks), stored: stored, title: title, log: log);

  Future<PrintResult> _run(
    Future<void> Function(PrintService svc) job, {
    required String stored,
    required String title,
    required bool log,
  }) async {
    PrintResult result;
    final connection = _ref.read(connectionControllerProvider.notifier);
    var transport = connection.transport;

    // Match the expected paired-printer workflow: reconnect to the last
    // selected printer automatically when the user starts a print job.
    if (transport == null || !transport.isConnected) {
      try {
        final reconnected = await connection.reconnectLast();
        if (reconnected) transport = connection.transport;
      } catch (_) {
        // The normal print error below reports that no connection is available.
      }
    }

    if (transport == null || !transport.isConnected) {
      result = const PrintResult.fail(kNoPrinterError);
    } else {
      try {
        final settings = _ref.read(settingsProvider).toPrintSettings();
        await job(PrintService(transport, settings));
        result = const PrintResult.ok();
      } catch (e) {
        result = PrintResult.fail(e.toString().replaceFirst('Exception: ', ''));
      }
    }

    if (log) {
      await _ref.read(historyRepositoryProvider).add(HistoryEntry(
            title: title,
            content: stored,
            success: result.ok,
            error: result.error,
            createdAt: DateTime.now(),
          ));
      _ref.invalidate(historyProvider);
    }
    return result;
  }
}
