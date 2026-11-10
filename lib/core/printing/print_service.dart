import 'dart:typed_data';
import 'dart:ui' as ui;
import 'escpos_commands.dart';
import 'print_block.dart';
import 'printer_transport.dart';
import 'raster_encoder.dart';
import 'receipt_renderer.dart';

/// إعدادات الطباعة المستخدمة داخل المحرك (مستقلة عن واجهة الإعدادات)
class PrintSettings {
  const PrintSettings({
    this.paperWidthMm = 58,
    this.density = 1,
    this.autoCut = true,
    this.tailFeedMm = 20,
    this.fontFamily,
  });

  final int paperWidthMm; // 58 أو 80
  final int density; // 0 فاتح، 1 عادي، 2 غامق
  final bool autoCut;
  final int tailFeedMm; // التغذية بعد كل إيصال
  final String? fontFamily;

  /// عرض الطباعة بالنقاط (203dpi): 58مم=384، 80مم=576
  int get widthDots => paperWidthMm >= 80 ? 576 : 384;
  int get threshold => const [105, 128, 165][density.clamp(0, 2)];
}

class PrintCancelled implements Exception {
  @override
  String toString() => 'تم إلغاء الطباعة';
}

/// خدمة الطباعة: تحوّل الـ Blocks إلى صورة ثم أوامر ESC/POS وترسلها.
class PrintService {
  PrintService(this.transport, this.settings);

  final PrinterTransport transport;
  final PrintSettings settings;

  // يمنع تداخل أوامر وظيفتي طباعة عند استدعاء الخدمة بالتزامن.
  Future<void> _queue = Future<void>.value();

  Future<void> _enqueue(Future<void> Function() action) {
    final next = _queue.then((_) => action());
    // لا نترك فشل مهمة سابقة يمنع تنفيذ المهام التالية.
    _queue = next.then<void>(
      (_) {},
      onError: (Object error, StackTrace stack) {},
    );
    return next;
  }

  /// طباعة قائمة عناصر (تدعم CutBlock لتقسيم الإيصال لعدة قطع)
  Future<void> printBlocks(List<PrintBlock> blocks, {bool Function()? isCancelled}) =>
      _enqueue(() => _printBlocks(blocks, isCancelled: isCancelled));

  Future<void> _printBlocks(List<PrintBlock> blocks, {bool Function()? isCancelled}) async {
    final segments = <List<PrintBlock>>[[]];
    final cutAfter = <bool>[];
    for (final b in blocks) {
      if (b is CutBlock) {
        cutAfter.add(true);
        segments.add([]);
      } else {
        segments.last.add(b);
      }
    }
    cutAfter.add(false); // آخر قطعة: القص حسب الإعداد

    await transport.write(EscPos().initialize().build());

    final renderer = ReceiptRenderer(
      widthDots: settings.widthDots,
      fontFamily: settings.fontFamily,
    );

    for (var i = 0; i < segments.length; i++) {
      if (isCancelled?.call() ?? false) throw PrintCancelled();
      final seg = segments[i];
      if (seg.isEmpty) {
        if (cutAfter[i]) await _cutPaper();
        continue;
      }
      final image = await renderer.render(seg);
      try {
        await _printImage(image);
      } finally {
        image.dispose();
      }
      await _feedMm(settings.tailFeedMm);
      final isLast = i == segments.length - 1;
      if (cutAfter[i] || (isLast && settings.autoCut)) await _cutPaper();
    }
  }

  /// طباعة صورة كاملة كإيصال: تهيئة ← صورة ← تغذية ← قص (حسب الإعدادات)
  Future<void> printImageJob(ui.Image image) => _enqueue(() async {
        await transport.write(EscPos().initialize().build());
        await _printImage(image);
        await _feedMm(settings.tailFeedMm);
        if (settings.autoCut) await _cutPaper();
      });

  /// طباعة صورة جاهزة كعملية مستقلة داخل طابور الطباعة.
  Future<void> printImage(ui.Image image) => _enqueue(() => _printImage(image));

  Future<void> _printImage(ui.Image image) async {
    final bytes = await RasterEncoder.encode(image, threshold: settings.threshold);
    await transport.write(bytes);
  }

  /// نص ASCII فقط عبر خطوط الطابعة (للعربية استخدم printBlocks)
  Future<void> printRawText(String text,
      {PrintAlign align = PrintAlign.left, bool bold = false, int size = 1}) =>
      _enqueue(() async {
        final cmd = EscPos().align(align).bold(bold).textSize(size, size).text(text);
        cmd.bold(false).textSize(1, 1);
        await transport.write(cmd.build());
      });

  /// QR أصلي من الطابعة
  Future<void> printQrNative(String data, {int moduleSize = 6}) =>
      _enqueue(() => transport.write(
          EscPos().align(PrintAlign.center).qrNative(data, moduleSize: moduleSize).newLine().build()));

  /// باركود Code128 أصلي من الطابعة
  Future<void> printBarcodeNative(String data) =>
      _enqueue(() => transport.write(
          EscPos().align(PrintAlign.center).barcodeNative(data).newLine().build()));

  Future<void> feedMm(int mm) => _enqueue(() => _feedMm(mm));

  Future<void> _feedMm(int mm) async {
    if (mm <= 0) return;
    await transport.write(EscPos().feedDots(mm * 8).build());
  }

  Future<void> feedLines(int n) =>
      _enqueue(() => transport.write(EscPos().feedLines(n).build()));

  Future<void> cutPaper({bool partial = true}) =>
      _enqueue(() => _cutPaper(partial: partial));

  Future<void> _cutPaper({bool partial = true}) =>
      transport.write(EscPos().cut(partial: partial).build());

  Future<void> sendRaw(Uint8List bytes) => _enqueue(() => transport.write(bytes));
}
